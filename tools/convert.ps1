$dir = $Args[0]
$files = Get-ChildItem -Path $dir -Filter 0x*.png
foreach ($file in $files)
{
    $out = $file.Name.Replace(".png",".bmp")    
    & "c:\Program Files\ImageMagick-7.0.10-Q16\magick.exe" "$dir\$file" -verbose -interpolate Nearest -filter Point -resize 128x128 -alpha Off -colors 256 "BMP3:$dir\$out"
}

# setlocal
# set PATH=%PATH%;"c:\Program Files\ImageMagick-7.0.10-Q16"
# 
# for /f %%f in ('dir /b %1\0x*.png') do echo "%%~ni"
# REM magick "%1\%%f" "%1\%%~ni"
