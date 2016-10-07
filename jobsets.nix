{ nixpkgs ? <nixpkgs>, declInput ? {} }:

let
  pkgs = import nixpkgs {};
  defaultSettings = {
    enabled = true;
    hidden = false;
    description = "";
    input = "nixpkgs";
    path = "pkgs/top-level/release.nix";
    keep = 1;
    shares = 42;
    interval = 60;
    inputs = {
      nixpkgs = {
        type = "git";
        value = "git://github.com/mayflower/nixpkgs";
      };
      supportedSystems = {
        type = "nix";
        value = ''[ \"x86_64-linux\" \"x86_64-darwin\" ]'';
      };
    };
    mail = true;
    mailOverride = "devnull+hydra@mayflower.de";
  };
  prs = builtins.fromJSON (builtins.readFile ./prs.json);
  jobsetsAttrs = with pkgs.lib; mapAttrs (name: settings: defaultSettings // settings) (genAttrs prs (name: {
    inputs = defaultSettings.inputs // {
      nixpkgs = defaultSettings.inputs.nixpkgs // {
        value = "${defaultSettings.inputs.nixpkgs.value} ${name}";
      };
    };
  }));
  fileContents = with pkgs.lib; ''
    cat > $out <<EOF
    {
      ${concatStringsSep "," (mapAttrsToList (name: settings: ''
        "${name}": {
            "enabled": ${if settings.enabled then "1" else "0"},
            "hidden": ${if settings.hidden then "true" else "false"},
            "description": "${settings.description}",
            "nixexprinput": "${settings.input}",
            "nixexprpath": "${settings.path}",
            "checkinterval": ${toString settings.interval},
            "schedulingshares": ${toString settings.shares},
            "enableemail": ${if settings.mail then "true" else "false"},
            "emailoverride": "${settings.mailOverride}",
            "keepnr": ${toString settings.keep},
            "inputs": {
              ${concatStringsSep "," (mapAttrsToList (inputName: inputSettings: ''
                "${inputName}": { "type": "${inputSettings.type}", "value": "${inputSettings.value}", "emailresponsible": false }
              '') settings.inputs)}
            }
        }
      '') jobsetsAttrs)}
    }
    EOF
  '';
in {
  jobsets = pkgs.runCommand "spec.json" {} fileContents;
}
