#:property PublishAot=false
#:property JsonSerializerIsReflectionEnabledByDefault=true
#:package CliWrap@3.*

using CliWrap;
using CliWrap.Buffered;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

// --- Arg parsing ---

string? baseRef = null;
string? headRef = null;
int maxLines = 40;
string? outputDir = null;
string prefix = "delve-chunk";

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--base" when i + 1 < args.Length:
            baseRef = args[++i];
            break;
        case "--head" when i + 1 < args.Length:
            headRef = args[++i];
            break;
        case "--max-lines" when i + 1 < args.Length:
            maxLines = int.Parse(args[++i]);
            break;
        case "--output-dir" when i + 1 < args.Length:
            outputDir = args[++i];
            break;
        case "--prefix" when i + 1 < args.Length:
            prefix = args[++i];
            break;
        default:
            Console.Error.WriteLine($"Unknown argument: {args[i]}");
            Environment.Exit(1);
            break;
    }
}

if (baseRef is null)
{
    Console.Error.WriteLine("Error: --base is required.");
    Environment.Exit(1);
}

if (outputDir is null)
{
    Console.Error.WriteLine("Error: --output-dir is required.");
    Environment.Exit(1);
}

headRef ??= "HEAD";

// --- Run git diff ---

var diffOutput = RunGit($"diff --no-color --no-ext-diff {baseRef} {headRef}");

// --- Parse into file blocks, then hunks ---

var fileBlocks = ParseFileBlocks(diffOutput);

// --- Build chunks ---

var chunks = new List<ChunkInfo>();
int chunkIndex = 0;

foreach (var fileBlock in fileBlocks)
{
    if (fileBlock.Binary)
    {
        // Binary files get their own chunk with just the header
        chunks.Add(new ChunkInfo
        {
            Index = chunkIndex++,
            Lines = fileBlock.Header.Count(c => c == '\n') + 1,
            Oversized = false,
            Path = fileBlock.NewPath ?? fileBlock.OldPath ?? "(unknown)",
            OldPath = fileBlock.OldPath != fileBlock.NewPath ? fileBlock.OldPath : null,
            ChangeType = fileBlock.ChangeType,
            Binary = true,
            HunkHeaders = [],
            HunkCount = 0,
            Content = fileBlock.Header
        });
        continue;
    }

    if (fileBlock.Hunks.Count == 0)
    {
        // Header-only changes (mode changes, empty files)
        chunks.Add(new ChunkInfo
        {
            Index = chunkIndex++,
            Lines = CountLines(fileBlock.Header),
            Oversized = false,
            Path = fileBlock.NewPath ?? fileBlock.OldPath ?? "(unknown)",
            OldPath = fileBlock.OldPath != fileBlock.NewPath ? fileBlock.OldPath : null,
            ChangeType = fileBlock.ChangeType,
            Binary = false,
            HunkHeaders = [],
            HunkCount = 0,
            Content = fileBlock.Header
        });
        continue;
    }

    // Greedy packing: accumulate hunks until adding the next would exceed maxLines
    var currentHunks = new List<HunkInfo>();
    int currentLineCount = CountLines(fileBlock.Header);

    foreach (var hunk in fileBlock.Hunks)
    {
        int hunkLines = CountLines(hunk.RawText);

        if (currentHunks.Count == 0)
        {
            // First hunk always goes into the current chunk
            currentHunks.Add(hunk);
            currentLineCount += hunkLines;
            continue;
        }

        if (currentLineCount + hunkLines <= maxLines)
        {
            // Fits, add it
            currentHunks.Add(hunk);
            currentLineCount += hunkLines;
        }
        else
        {
            // Doesn't fit, flush current chunk and start a new one
            chunks.Add(BuildChunk(chunkIndex++, fileBlock, currentHunks, currentLineCount));
            currentHunks = [hunk];
            currentLineCount = CountLines(fileBlock.Header) + hunkLines;
        }
    }

    // Flush remaining hunks
    if (currentHunks.Count > 0)
    {
        chunks.Add(BuildChunk(chunkIndex++, fileBlock, currentHunks, currentLineCount));
    }
}

// --- Write chunk files and manifest ---

Directory.CreateDirectory(outputDir);

foreach (var chunk in chunks)
{
    var fileName = $"{prefix}-{chunk.Index:D2}.diff";
    chunk.File = fileName;
    var filePath = Path.Combine(outputDir, fileName);
    File.WriteAllText(filePath, chunk.Content);
    chunk.Oversized = chunk.Lines > maxLines;
}

// Build manifest
var manifest = new Manifest
{
    Base = baseRef!,
    Head = headRef,
    MaxLines = maxLines,
    OutputDir = Path.GetFullPath(outputDir),
    Chunks = chunks.Select(c => new ManifestChunk
    {
        Index = c.Index,
        File = c.File!,
        Lines = c.Lines,
        Oversized = c.Oversized,
        Path = c.Path,
        OldPath = c.OldPath,
        ChangeType = c.ChangeType,
        Binary = c.Binary,
        HunkHeaders = c.HunkHeaders,
        HunkCount = c.HunkCount,
    }).ToList()
};

var jsonOptions = new JsonSerializerOptions
{
    WriteIndented = true,
    PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
};
Console.WriteLine(JsonSerializer.Serialize(manifest, jsonOptions));

// =============================================================================
// Helper methods
// =============================================================================

static string RunGit(string arguments)
{
    var result = Cli.Wrap("git")
        .WithArguments(arguments)
        .WithValidation(CommandResultValidation.None)
        .ExecuteBufferedAsync()
        .GetAwaiter()
        .GetResult();

    if (result.ExitCode != 0)
    {
        Console.Error.WriteLine($"git {arguments} failed (exit {result.ExitCode}):");
        Console.Error.WriteLine(result.StandardError);
        Environment.Exit(2);
    }
    return result.StandardOutput;
}

static List<FileBlock> ParseFileBlocks(string diffOutput)
{
    var blocks = new List<FileBlock>();
    if (string.IsNullOrEmpty(diffOutput)) return blocks;

    // Split on "diff --git" boundaries, keeping the delimiter
    var fileParts = Regex.Split(diffOutput, @"(?=^diff --git )", RegexOptions.Multiline);

    foreach (var part in fileParts)
    {
        if (string.IsNullOrWhiteSpace(part) || !part.StartsWith("diff --git "))
            continue;

        var block = new FileBlock();

        // Extract paths from the "diff --git a/... b/..." line
        var firstLine = part[..part.IndexOf('\n')];
        var pathMatch = Regex.Match(firstLine, @"^diff --git a/(.+) b/(.+)$");
        if (pathMatch.Success)
        {
            block.OldPath = pathMatch.Groups[1].Value;
            block.NewPath = pathMatch.Groups[2].Value;
        }

        // Detect change type
        if (part.Contains("\nnew file mode"))
            block.ChangeType = "added";
        else if (part.Contains("\ndeleted file mode"))
            block.ChangeType = "deleted";
        else if (part.Contains("\nrename from") || part.Contains("\nsimilarity index"))
            block.ChangeType = "renamed";
        else
            block.ChangeType = "modified";

        // Detect binary
        if (part.Contains("\nBinary files") || part.Contains("\nGIT binary patch"))
        {
            block.Binary = true;
            block.Header = part;
            blocks.Add(block);
            continue;
        }

        // Split into header and hunks at the first @@ marker
        var firstHunkIdx = part.IndexOf("\n@@");
        if (firstHunkIdx == -1)
        {
            // No hunks (e.g., mode-only change)
            block.Header = part;
            blocks.Add(block);
            continue;
        }

        // Header is everything up to (not including) the first @@
        block.Header = part[..(firstHunkIdx + 1)]; // include the \n

        // Parse hunks
        var hunkSection = part[(firstHunkIdx + 1)..];
        var hunkParts = Regex.Split(hunkSection, @"(?=^@@)", RegexOptions.Multiline);

        foreach (var hunkPart in hunkParts)
        {
            if (string.IsNullOrWhiteSpace(hunkPart) || !hunkPart.StartsWith("@@"))
                continue;

            var hunk = new HunkInfo { RawText = hunkPart };

            // Extract the @@ header line
            var headerEnd = hunkPart.IndexOf('\n');
            hunk.HeaderLine = headerEnd >= 0 ? hunkPart[..headerEnd] : hunkPart;

            block.Hunks.Add(hunk);
        }

        blocks.Add(block);
    }

    return blocks;
}

static int CountLines(string text)
{
    if (string.IsNullOrEmpty(text)) return 0;

    int count = 1;
    foreach (var c in text)
    {
        if (c == '\n') count++;
    }
    // Don't count a trailing newline as an extra line
    if (text.Length > 0 && text[^1] == '\n') count--;
    return count;
}

static ChunkInfo BuildChunk(int index, FileBlock fileBlock, List<HunkInfo> hunks, int lineCount)
{
    var sb = new StringBuilder();
    sb.Append(fileBlock.Header);
    foreach (var h in hunks)
        sb.Append(h.RawText);

    return new ChunkInfo
    {
        Index = index,
        Lines = lineCount,
        Path = fileBlock.NewPath ?? fileBlock.OldPath ?? "(unknown)",
        OldPath = fileBlock.OldPath != fileBlock.NewPath ? fileBlock.OldPath : null,
        ChangeType = fileBlock.ChangeType,
        Binary = false,
        HunkHeaders = hunks.Select(h => h.HeaderLine).ToList(),
        HunkCount = hunks.Count,
        Content = sb.ToString(),
    };
}

// =============================================================================
// Types
// =============================================================================

class FileBlock
{
    public string? OldPath { get; set; }
    public string? NewPath { get; set; }
    public string ChangeType { get; set; } = "modified";
    public bool Binary { get; set; }
    public string Header { get; set; } = "";
    public List<HunkInfo> Hunks { get; set; } = [];
}

class HunkInfo
{
    public string HeaderLine { get; set; } = "";
    public string RawText { get; set; } = "";
}

class ChunkInfo
{
    public int Index { get; set; }
    public string? File { get; set; }
    public int Lines { get; set; }
    public bool Oversized { get; set; }
    public string Path { get; set; } = "";
    public string? OldPath { get; set; }
    public string ChangeType { get; set; } = "modified";
    public bool Binary { get; set; }
    public List<string> HunkHeaders { get; set; } = [];
    public int HunkCount { get; set; }
    [JsonIgnore]
    public string Content { get; set; } = "";
}

class Manifest
{
    public string Base { get; set; } = "";
    public string Head { get; set; } = "";
    public int MaxLines { get; set; }
    public string OutputDir { get; set; } = "";
    public List<ManifestChunk> Chunks { get; set; } = [];
}

class ManifestChunk
{
    public int Index { get; set; }
    public string File { get; set; } = "";
    public int Lines { get; set; }
    public bool Oversized { get; set; }
    public string Path { get; set; } = "";
    public string? OldPath { get; set; }
    public string ChangeType { get; set; } = "modified";
    public bool Binary { get; set; }
    public List<string> HunkHeaders { get; set; } = [];
    public int HunkCount { get; set; }
}
