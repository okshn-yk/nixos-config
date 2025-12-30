{ config, pkgs, ... }:

{
  # Keyboard Remapping (xremap)

  services.xremap = {
    enable = true;
    withGnome = true;
    userName = "okshin";
    deviceNames = [ "AT Translated Set 2 keyboard" ];
    yamlConfig = ''
      modmap:
        - name: Onishi Layout (Base)
          remap:
            minus: slash
            # --- Upper ---
            w: l
            e: u
            r: f
            t: dot
            y: comma
            u: w
            i: r
            o: y
            # --- Middle ---
            a: e
            s: i
            d: a
            f: o
            g: minus
            h: k
            j: t
            k: n
            l: s
            semicolon: h
            # --- Lower ---
            b: semicolon
            n: g
            m: d
            comma: m
            dot: j
            slash: b
    '';
  };
}
