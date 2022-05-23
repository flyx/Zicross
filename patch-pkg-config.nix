pkgs: pkgs.writeShellScript "patch-pkg-config" ''
  pcFile=$1
  storePath=''$2
  origPath=''${3:-/}
  echo patching $pcFile to store path $storePath
  if [[ $origPath == */ ]]; then
    s="s:=$origPath:=$storePath/:g"
  else
    s="s:=$origPath:=$storePath:g"
  fi
  ${pkgs.gnused}/bin/sed -i $s $pcFile
''