[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceImagePath
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not ('Mantra.IconAssetBuilder' -as [type])) {
  Add-Type -Language CSharp -ReferencedAssemblies 'System.Drawing' -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

namespace Mantra
{
    public static class IconAssetBuilder
    {
        private static Bitmap ResizeBitmap(Image source, int size, Color clearColor)
        {
            var bitmap = new Bitmap(size, size, PixelFormat.Format32bppArgb);
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.Clear(clearColor);
                graphics.CompositingMode = CompositingMode.SourceOver;
                graphics.CompositingQuality = CompositingQuality.HighQuality;
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                graphics.SmoothingMode = SmoothingMode.HighQuality;
                graphics.DrawImage(source, 0, 0, size, size);
            }

            return bitmap;
        }

        private static int ClampChannel(double value)
        {
            if (value < 0)
            {
                return 0;
            }

            if (value > 255)
            {
                return 255;
            }

            return (int)Math.Round(value);
        }

        public static Bitmap ExtractForegroundFromWhite(Bitmap source)
        {
            var bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);

            for (var y = 0; y < source.Height; y++)
            {
                for (var x = 0; x < source.Width; x++)
                {
                    var pixel = source.GetPixel(x, y);
                    var alpha = 255 - Math.Min(pixel.R, Math.Min(pixel.G, pixel.B));

                    if (alpha < 8)
                    {
                        bitmap.SetPixel(x, y, Color.FromArgb(0, 0, 0, 0));
                        continue;
                    }

                    var red = ClampChannel((255.0 * (pixel.R - 255 + alpha)) / alpha);
                    var green = ClampChannel((255.0 * (pixel.G - 255 + alpha)) / alpha);
                    var blue = ClampChannel((255.0 * (pixel.B - 255 + alpha)) / alpha);

                    bitmap.SetPixel(x, y, Color.FromArgb(alpha, red, green, blue));
                }
            }

            return bitmap;
        }

        public static string GetCornerHexColor(string sourcePath)
        {
            using (var source = new Bitmap(sourcePath))
            {
                var pixel = source.GetPixel(0, 0);
                return string.Format("#{0:X2}{1:X2}{2:X2}", pixel.R, pixel.G, pixel.B);
            }
        }

        public static void SaveResizedPng(string sourcePath, string destinationPath, int size)
        {
            using (var source = new Bitmap(sourcePath))
            using (var resized = ResizeBitmap(source, size, Color.Transparent))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                resized.Save(destinationPath, ImageFormat.Png);
            }
        }

        public static void SaveForegroundPng(string sourcePath, string destinationPath, int size)
        {
            using (var source = new Bitmap(sourcePath))
            using (var foreground = ExtractForegroundFromWhite(source))
            using (var resized = ResizeBitmap(foreground, size, Color.Transparent))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));
                resized.Save(destinationPath, ImageFormat.Png);
            }
        }

        public static void SaveIco(string sourcePath, string destinationPath, int[] sizes)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(destinationPath));

            using (var source = new Bitmap(sourcePath))
            {
                var payloads = new byte[sizes.Length][];

                for (var index = 0; index < sizes.Length; index++)
                {
                    using (var resized = ResizeBitmap(source, sizes[index], Color.Transparent))
                    using (var stream = new MemoryStream())
                    {
                        resized.Save(stream, ImageFormat.Png);
                        payloads[index] = stream.ToArray();
                    }
                }

                using (var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write))
                using (var writer = new BinaryWriter(fileStream))
                {
                    writer.Write((ushort)0);
                    writer.Write((ushort)1);
                    writer.Write((ushort)sizes.Length);

                    var offset = 6 + (sizes.Length * 16);
                    for (var index = 0; index < sizes.Length; index++)
                    {
                        var size = sizes[index];
                        var payload = payloads[index];

                        writer.Write((byte)(size >= 256 ? 0 : size));
                        writer.Write((byte)(size >= 256 ? 0 : size));
                        writer.Write((byte)0);
                        writer.Write((byte)0);
                        writer.Write((ushort)1);
                        writer.Write((ushort)32);
                        writer.Write(payload.Length);
                        writer.Write(offset);

                        offset += payload.Length;
                    }

                    for (var index = 0; index < payloads.Length; index++)
                    {
                        writer.Write(payloads[index]);
                    }
                }
            }
        }
    }
}
"@
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$resolvedSourcePath = (Resolve-Path -LiteralPath $SourceImagePath).ProviderPath

$sourceCopyPath = Join-Path $repoRoot 'assets\branding\mantra_app_icon_source.png'
$foregroundCopyPath = Join-Path $repoRoot 'assets\branding\mantra_app_icon_foreground.png'

Copy-Item -LiteralPath $resolvedSourcePath -Destination $sourceCopyPath -Force
[Mantra.IconAssetBuilder]::SaveForegroundPng($resolvedSourcePath, $foregroundCopyPath, 1024)

$androidLegacyIcons = @(
  @{ Path = 'android\app\src\main\res\mipmap-mdpi\ic_launcher.png'; Size = 48 },
  @{ Path = 'android\app\src\main\res\mipmap-mdpi\ic_launcher_round.png'; Size = 48 },
  @{ Path = 'android\app\src\main\res\mipmap-hdpi\ic_launcher.png'; Size = 72 },
  @{ Path = 'android\app\src\main\res\mipmap-hdpi\ic_launcher_round.png'; Size = 72 },
  @{ Path = 'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png'; Size = 96 },
  @{ Path = 'android\app\src\main\res\mipmap-xhdpi\ic_launcher_round.png'; Size = 96 },
  @{ Path = 'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png'; Size = 144 },
  @{ Path = 'android\app\src\main\res\mipmap-xxhdpi\ic_launcher_round.png'; Size = 144 },
  @{ Path = 'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png'; Size = 192 },
  @{ Path = 'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher_round.png'; Size = 192 }
)

foreach ($icon in $androidLegacyIcons) {
  [Mantra.IconAssetBuilder]::SaveResizedPng(
    $resolvedSourcePath,
    (Join-Path $repoRoot $icon.Path),
    $icon.Size
  )
}

[Mantra.IconAssetBuilder]::SaveForegroundPng(
  $resolvedSourcePath,
  (Join-Path $repoRoot 'android\app\src\main\res\drawable-nodpi\ic_launcher_foreground.png'),
  250
)

$iosIcons = @(
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png'; Size = 20 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png'; Size = 40 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png'; Size = 60 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png'; Size = 29 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png'; Size = 58 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png'; Size = 87 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png'; Size = 40 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png'; Size = 80 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png'; Size = 120 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png'; Size = 120 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png'; Size = 180 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png'; Size = 76 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png'; Size = 152 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png'; Size = 167 },
  @{ Path = 'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png'; Size = 1024 }
)

foreach ($icon in $iosIcons) {
  [Mantra.IconAssetBuilder]::SaveResizedPng(
    $resolvedSourcePath,
    (Join-Path $repoRoot $icon.Path),
    $icon.Size
  )
}

$macIcons = @(
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png'; Size = 16 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png'; Size = 32 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png'; Size = 64 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png'; Size = 128 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png'; Size = 256 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png'; Size = 512 },
  @{ Path = 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png'; Size = 1024 }
)

foreach ($icon in $macIcons) {
  [Mantra.IconAssetBuilder]::SaveResizedPng(
    $resolvedSourcePath,
    (Join-Path $repoRoot $icon.Path),
    $icon.Size
  )
}

$webIcons = @(
  @{ Path = 'web\favicon.png'; Size = 64 },
  @{ Path = 'web\icons\Icon-192.png'; Size = 192 },
  @{ Path = 'web\icons\Icon-512.png'; Size = 512 },
  @{ Path = 'web\icons\Icon-maskable-192.png'; Size = 192 },
  @{ Path = 'web\icons\Icon-maskable-512.png'; Size = 512 }
)

foreach ($icon in $webIcons) {
  [Mantra.IconAssetBuilder]::SaveResizedPng(
    $resolvedSourcePath,
    (Join-Path $repoRoot $icon.Path),
    $icon.Size
  )
}

[Mantra.IconAssetBuilder]::SaveIco(
  $resolvedSourcePath,
  (Join-Path $repoRoot 'windows\runner\resources\app_icon.ico'),
  [int[]]@(16, 32, 48, 64, 128, 256)
)

$backgroundColor = [Mantra.IconAssetBuilder]::GetCornerHexColor($resolvedSourcePath)
Write-Host "App icons atualizados a partir de '$resolvedSourcePath'." -ForegroundColor Green
Write-Host "Cor de fundo do icone fonte: $backgroundColor" -ForegroundColor DarkCyan
