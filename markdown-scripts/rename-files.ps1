$files = dir *.yml,*.md -rec
$names = @{
  "finding-items"="finding-packages"
  "publishing-items"="publishing-packages"
  "working-with-items"="working-with-packages"
  "item-manifest-affecting-ui" = "package-manifest-affecting-ui"
  "filtering-items" = "filtering-packages"
  "deleting-items" = "deleting-packages"
  "managing-item-owners" = "managing-package-owners"
  "publishing-an-item" = "publishing-a-package"
  "publishing-an-package" = "publishing-a-package"
  "unlisting-items" = "unlisting-packages"
  "contacting-item-owners" = "contacting-package-owners"
  "items-that-require-license-acceptance" = "packages-that-require-license-acceptance"
  "ItemDisplayPageWithPSEditions.PNG" = "manual_package_download.png"
  "Manual_Item_Download.PNG" = "packagedisplaypagewithpseditions.png"
}

foreach ($file in $files) {
  write-host $file
  $mdlines = Get-Content $file -Encoding utf8
  for ($x=0; $x -lt $mdlines.Length;$x++) {
    $line = $mdlines[$x]
    foreach ($key in $names.Keys) {
      $mdlines[$x] = $mdlines[$x] -replace $key,$names["$key"]
    }
  }
  Set-Content -path $file -Value $mdlines -Encoding utf8 -Force
}
