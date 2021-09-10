dir *.md -rec | %{
  $mdtext = gc $_ -enc byte 

  if ($mdtext -gt 0x7f) {
    $_.fullname  
  }
} # end foreach file