{lib, ...}: let
  inherit (lib.strings) removeSuffix;
in rec {
  wrapFunction = content: "function()\n${content}\nend";
  wrapReturnFunction = content: "return ${wrapFunction content}";
  wrapSelfInvokingFunction = {
    section,
    lua,
  }: ''
    -- begin ${section}
    (${wrapFunction (removeSuffix "\n" lua)})();
    -- end ${section}
  '';
}
