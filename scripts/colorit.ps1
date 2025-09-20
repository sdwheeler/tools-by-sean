# https://www.levibotelho.com/development/calculate-the-best-text-colour-for-a-given-background/
function colorit {
    param ([string]$color, [string]$name)
    $rgb = ([uint32]"0x$($color)")
    $r = ($rgb -band 0x00ff0000) -shr 16
    $g = ($rgb -band 0x0000ff00) -shr 8
    $b =  $rgb -band 0x000000ff
    $bg = $PSStyle.Background.FromRgb($rgb)
    [int]$luma = [math]::Sqrt(
        [math]::Pow($r, 2) * 0.299 +
        [math]::Pow($g, 2) * 0.587 +
        [math]::Pow($b, 2) * 0.114
    )
    if ($luma -gt 186) {
        $fg = $PSStyle.Foreground.Black
    } else {
        $fg = $PSStyle.Foreground.BrightWhite
    }
    $fg + $bg + $name + $PSStyle.Reset + "`tluma: $luma, rgb: $r,$g,$b"
}