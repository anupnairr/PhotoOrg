using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using MetadataExtractor;
using MetadataExtractor.Formats.Exif;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Threading.Tasks;

namespace PhotoOrgApp
{
    public partial class MainWindow : Window
    {
        private bool _isRunning = false;

        private static readonly string[] ValidTypes = {
            ".jpg",".jpeg",".heic",".heif",".png",".gif",
            ".bmp",".tiff",".tif",".webp",".mp4",".mov",
            ".avi",".mkv",".3gp",".wmv",".mpg",".mpeg",
            ".vob",".m4v",".flv"
        };

        private static readonly string[] MonthNames = {
            "","01-Jan","02-Feb","03-Mar","04-Apr",
            "05-May","06-Jun","07-Jul","08-Aug",
            "09-Sep","10-Oct","11-Nov","12-Dec"
        };

        public MainWindow()
        {
            InitializeComponent();
            Log("PhotoOrg ready. Select source and output folders to begin.");
        }

        private async void BrowseSource_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFolderDialog { Title = "Select Source Folder" };
            var folder = await dialog.ShowAsync(this);
            if (folder != null)
            {
                SourcePathBox.Text = folder;
                Log("Source folder: " + folder);
                SetStatus("Source folder selected.");
            }
        }

        private async void BrowseOutput_Click(object sender, RoutedEventArgs e)
        {
            var dialog = new OpenFolderDialog { Title = "Select Output Folder" };
            var folder = await dialog.ShowAsync(this);
            if (folder != null)
            {
                OutputPathBox.Text = folder;
                Log("Output folder: " + folder);
                SetStatus("Ready to start organising.");
            }
        }

        private async void Start_Click(object sender, RoutedEventArgs e)
        {
            if (_isRunning) return;

            if (string.IsNullOrEmpty(SourcePathBox.Text))
            {
                Log("ERROR: Please select a source folder first.");
                return;
            }
            if (string.IsNullOrEmpty(OutputPathBox.Text))
            {
                Log("ERROR: Please select an output folder first.");
                return;
            }

            _isRunning = true;
            SetStatus("Running - please wait...");
            SetProgress(0);

            bool findDupes    = FindDupesCheck.IsChecked == true;
            bool openWhenDone = OpenWhenDoneCheck.IsChecked == true;
            string source     = SourcePathBox.Text;
            string output     = OutputPathBox.Text;

            await RunOrganiser(source, output, findDupes);

            _isRunning = false;

            if (openWhenDone)
                OpenFolder(Path.Combine(output, "Sorted"));
        }

        private async Task RunOrganiser(string source, string output, bool findDupes)
        {
            await Task.Run(() =>
            {
                try
                {
                    Log("Scanning source folder...");

                    var allFiles = System.IO.Directory
                        .GetFiles(source, "*.*", SearchOption.AllDirectories)
                        .Where(f => ValidTypes.Contains(
                            Path.GetExtension(f).ToLower()))
                        .ToList();

                    int total = allFiles.Count;
                    Log("Found " + total + " media files.");
                    SetProgress(5);

                    if (total == 0)
                    {
                        Log("No media files found. Check your source folder.");
                        SetStatus("No media files found.");
                        return;
                    }

                    string sortedDir = Path.Combine(output, "Sorted");
                    string dupesDir  = Path.Combine(output, "Duplicates_Review");
                    System.IO.Directory.CreateDirectory(sortedDir);
                    System.IO.Directory.CreateDirectory(dupesDir);

                    Log("Sorting files by date...");

                    int done   = 0;
                    int sorted = 0;
                    int noExif = 0;
                    int errors = 0;

                    foreach (var file in allFiles)
                    {
                        try
                        {
                            DateTime fileDate = GetExifDate(file);

                            if (fileDate == DateTime.MinValue)
                            {
                                fileDate = File.GetLastWriteTime(file);
                                noExif++;
                            }

                            int year  = fileDate.Year;
                            int month = fileDate.Month;

                            if (year < 1990 || year > 2030)
                            {
                                fileDate = File.GetLastWriteTime(file);
                                year     = fileDate.Year;
                                month    = fileDate.Month;
                            }

                            string monthFolder = MonthNames[month];
                            string destFolder  = Path.Combine(
                                sortedDir, year.ToString(), monthFolder);

                            System.IO.Directory.CreateDirectory(destFolder);

                            string destFile = Path.Combine(
                                destFolder, Path.GetFileName(file));

                            if (File.Exists(destFile))
                            {
                                string stamp = DateTime.Now.ToString("HHmmssff");
                                destFile = Path.Combine(destFolder,
                                    Path.GetFileNameWithoutExtension(file)
                                    + "_" + stamp
                                    + Path.GetExtension(file));
                            }

                            File.Move(file, destFile);
                            sorted++;
                        }
                        catch (Exception ex)
                        {
                            Log("Error: " + Path.GetFileName(file)
                                + " - " + ex.Message);
                            errors++;
                        }

                        done++;
                        SetProgress(5 + (int)((done / (float)total) * 75));
                    }

                    Log("Sorted: " + sorted + " | No EXIF: " + noExif
                        + " | Errors: " + errors);

                    if (findDupes)
                    {
                        Log("Scanning for duplicates...");
                        int dupes = FindAndMoveDuplicates(sortedDir, dupesDir);
                        Log("Duplicates moved: " + dupes);
                    }

                    CleanEmptyFolders(source);

                    SetProgress(100);
                    Log("─────────────────────────────────");
                    Log("Done!  Sorted  : " + sorted + " files");
                    Log("       No EXIF : " + noExif);
                    Log("       Errors  : " + errors);
                    Log("       Output  : " + sortedDir);
                    SetStatus("Finished! " + sorted + " files organised.");
                }
                catch (Exception ex)
                {
                    Log("Fatal error: " + ex.Message);
                    SetStatus("Error occurred. See log.");
                }
            });
        }

        private DateTime GetExifDate(string filePath)
        {
            try
            {
                var dirs = ImageMetadataReader.ReadMetadata(filePath);

                var exifSub = dirs.OfType<ExifSubIfdDirectory>().FirstOrDefault();
                if (exifSub != null)
                    if (exifSub.TryGetDateTime(
                        ExifDirectoryBase.TagDateTimeOriginal, out var dt))
                        return dt;

                var exifIfd = dirs.OfType<ExifIfd0Directory>().FirstOrDefault();
                if (exifIfd != null)
                    if (exifIfd.TryGetDateTime(
                        ExifDirectoryBase.TagDateTime, out var dt))
                        return dt;
            }
            catch { }

            return DateTime.MinValue;
        }

        private int FindAndMoveDuplicates(string sortedDir, string dupesDir)
        {
            int dupeCount = 0;
            try
            {
                var allSorted = System.IO.Directory
                    .GetFiles(sortedDir, "*.*", SearchOption.AllDirectories)
                    .Where(f => ValidTypes.Contains(
                        Path.GetExtension(f).ToLower()))
                    .ToList();

                var sizeGroups = allSorted
                    .GroupBy(f => new FileInfo(f).Length)
                    .Where(g => g.Count() > 1);

                var hashTable = new Dictionary<string, string>();

                foreach (var group in sizeGroups)
                {
                    foreach (var file in group)
                    {
                        string hash = ComputeMD5(file);
                        if (hash == null) continue;

                        if (hashTable.ContainsKey(hash))
                        {
                            string dupeDest = Path.Combine(
                                dupesDir, Path.GetFileName(file));

                            if (File.Exists(dupeDest))
                            {
                                string stamp = DateTime.Now.ToString("HHmmssff");
                                dupeDest = Path.Combine(dupesDir,
                                    Path.GetFileNameWithoutExtension(file)
                                    + "_" + stamp
                                    + Path.GetExtension(file));
                            }

                            File.Move(file, dupeDest);
                            dupeCount++;
                        }
                        else
                        {
                            hashTable[hash] = file;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Duplicate scan error: " + ex.Message);
            }
            return dupeCount;
        }

        private string ComputeMD5(string filePath)
        {
            try
            {
                using var md5    = MD5.Create();
                using var stream = File.OpenRead(filePath);
                var hash         = md5.ComputeHash(stream);
                return BitConverter.ToString(hash).Replace("-", "");
            }
            catch { return null; }
        }

        private void CleanEmptyFolders(string path)
        {
            try
            {
                foreach (var dir in System.IO.Directory
                    .GetDirectories(path, "*", SearchOption.AllDirectories)
                    .OrderByDescending(d => d.Length))
                {
                    if (!System.IO.Directory
                        .EnumerateFileSystemEntries(dir).Any())
                        System.IO.Directory.Delete(dir);
                }
            }
            catch { }
        }

        private void ClearLog_Click(object sender, RoutedEventArgs e)
        {
            LogBox.Text = "";
        }

        private void OpenOutput_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrEmpty(OutputPathBox.Text))
                OpenFolder(Path.Combine(OutputPathBox.Text, "Sorted"));
        }

        private void OpenFolder(string path)
        {
            try
            {
                if (System.IO.Directory.Exists(path))
                    Process.Start(new ProcessStartInfo
                    {
                        FileName        = path,
                        UseShellExecute = true
                    });
            }
            catch { }
        }

        private void Log(string message)
        {
            Dispatcher.UIThread.Post(() =>
            {
                string ts   = DateTime.Now.ToString("HH:mm:ss");
                LogBox.Text += "[" + ts + "] " + message + "\n";
                LogBox.CaretIndex = int.MaxValue;
            });
        }

        private void SetStatus(string message)
        {
            Dispatcher.UIThread.Post(() =>
            {
                StatusText.Text = message;
            });
        }

        private void SetProgress(int value)
        {
            Dispatcher.UIThread.Post(() =>
            {
                MainProgressBar.Value = value;
                ProgressLabel.Text    = value + "%";
            });
        }
    }
}
