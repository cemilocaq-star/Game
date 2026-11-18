#!/usr/bin/env python3
"""Builds assets/ui/icons/*.svg from a local clone of https://github.com/game-icons/icons
(game-icons.net, CC BY 3.0 unless noted). Strips the black background square so each glyph is white
on transparent and can be tinted in the game, and writes assets/ui/ICON_CREDITS.md.

Usage: python3 tools/build_ui_icons.py /path/to/game-icons/icons
The `badges` folder is skipped on purpose: its licence is not stated.
"""
import glob
import os
import sys

# semantic name used by the game -> game-icons.net file name
ICONS = {
    # weapons (one per weapon id in main.gd WEAPON_ORDER)
    "w_aether": "ray-gun", "w_minicore": "uzi", "w_hand_cannon": "revolver", "w_pulse_carbine": "m3-grease-gun",
    "w_star_piercer": "north-star-shuriken", "w_duck_launcher": "plastic-duck", "w_banana_boomerang": "banana",
    "w_confetti_cannon": "party-popper", "w_prism_scepter": "crystal-wand", "w_vortex_orbiter": "orbit",
    "w_comet_bow": "bow-arrow", "w_bubble_burst": "bubbles", "w_glitch_ray": "blaster", "w_meteor_mallet": "toy-mallet",
    "w_frost_wand": "snowflake-1", "w_solar_lance": "sun-spear", "w_slime_slinger": "slime", "w_pixel_storm": "lightning-storm",
    "w_thunder_drum": "drum", "w_moon_disc": "moon", "w_jellyfish_staff": "jellyfish", "w_portal_popper": "portal",
    "w_rubber_chicken": "chicken", "w_ranger_rifle": "winchester-rifle", "w_heavy_sidearm": "pistol-gun",
    "w_longshot": "arrow-scope", "w_rotary_arc": "minigun",
    # gear
    "grenade": "grenade", "reload": "reload-gun-barrel", "aim": "crosshair", "hit": "bullseye", "ammo": "bullets",
    # movement and actions
    "jump": "jump-across", "sprint": "sprint", "slide": "skateboarding-01", "dash": "fire-dash", "interact": "click",
    "emote": "party-hat",
    # navigation and system
    "settings": "gears", "inventory": "backpack", "customize": "shirt", "profile": "person", "scoreboard": "podium",
    "arsenal": "crossed-pistols", "admin": "key-card", "lobby": "three-friends", "play": "play-button", "quick_match": "rocket",
    "create_room": "house", "join_room": "door", "connect": "network-bars", "invite": "team-idea", "leave": "exit-door",
    "close": "cancel", "info": "info", "credits": "scroll-unfurled", "graphics": "cyber-eye", "sound": "sound-on", "menu": "hamburger-menu",
    "check": "check-mark", "globe": "globe", "trophy": "trophy-cup", "medal": "medal", "crown": "crown", "key": "key-card",
    # combat and status
    "health": "heart-plus", "stamina": "lungs", "shield": "shield", "xp": "star-formation", "kill": "skull-crossed-bones",
    "headshot": "eye-target", "assist": "two-shadows", "streak": "flame", "damage": "bleeding-wound", "death": "skull-bolt",
    "objective": "flag-objective", "timer": "stopwatch", "hourglass": "hourglass", "team": "shield", "coins": "coins",
    # events
    "e_duck_parade": "duck", "e_pink_sky": "sunset", "e_confetti_storm": "party-flags", "e_low_gravity": "feather",
    "e_golden_orb_rush": "gold-nuggets", "e_bonk_mode": "hammer-drop", "e_npc_mode": "robot-helmet", "e_ice_world": "ice-cube",
    "e_big_head": "brain", "e_duck_exe": "ghost", "e_meteor_shower": "meteor-impact", "e_freeze_frame": "frozen-orb",
    "e_reverse_panic": "cycle", "e_double_xp": "upgrade", "e_sunshine": "sun",
}

AUTHORS = {
    "lorc": "Lorc", "delapouite": "Delapouite", "skoll": "Skoll", "sbed": "Sbed", "lucasms": "Lucas",
    "carl-olsen": "Carl Olsen", "darkzaitzev": "DarkZaitzev", "zeromancer": "Zeromancer (CC0)",
    "andymeneely": "Andy Meneely", "john-colburn": "John Colburn", "felbrigg": "Felbrigg", "willdabeast": "Willdabeast",
    "faithtoken": "Faithtoken", "irongamer": "Irongamer", "heavenly-dog": "HeavenlyDog", "lord-berandas": "Lord Berandas",
    "priorblue": "PriorBlue", "viscious-speed": "Viscious Speed (CC0)", "john-redman": "John Redman", "sparker": "Sparker",
    "cathelineau": "Cathelineau", "aussiesim": "Aussiesim", "catsu": "Catsu", "caro-asercion": "Caro Asercion",
    "kier-heyl": "Kier Heyl", "rihlsul": "Rihlsul", "quoting": "Quoting", "guard13007": "Guard13007", "spencerdub": "SpencerDub",
    "generalace135": "GeneralAce135", "zajkonur": "Zajkonur", "starseeker": "Starseeker", "pepijn-poolman": "Pepijn Poolman",
    "pierre-leducq": "Pierre Leducq", "seregacthtuf": "SeregaCthtuf", "lucas": "Lucas",
}


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = sys.argv[1]
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "icons")
    os.makedirs(out_dir, exist_ok=True)
    credits = []
    missing = 0
    for name, file_name in sorted(ICONS.items()):
        matches = [p for p in sorted(glob.glob(os.path.join(src, "*", file_name + ".svg"))) if os.path.basename(os.path.dirname(p)) != "badges"]
        if not matches:
            print("MISSING", name, file_name)
            missing += 1
            continue
        path = matches[0]
        folder = os.path.basename(os.path.dirname(path))
        if folder not in AUTHORS:
            print("UNKNOWN AUTHOR FOLDER", folder, "for", file_name)
            return 1
        svg = open(path, encoding="utf-8").read()
        background = '<path d="M0 0h512v512H0z"/>'
        if background not in svg:
            print("UNEXPECTED SVG (no background square)", path)
            return 1
        svg = svg.replace(background, "")
        with open(os.path.join(out_dir, name + ".svg"), "w", encoding="utf-8") as handle:
            handle.write(svg)
        credits.append((name, file_name, AUTHORS[folder]))
    if missing:
        return 1
    lines = [
        "# UI icon credits", "",
        "The in-game icons come from [game-icons.net](https://game-icons.net) (repository https://github.com/game-icons/icons).",
        "They are licensed under [Creative Commons Attribution 3.0](https://creativecommons.org/licenses/by/3.0/)",
        "(CC0 where marked). Icons made by Lorc, Delapouite and other contributors listed below.",
        "Changes: the black background square of each file was removed so the glyph is white on transparent and can be tinted.",
        "Regenerate with `python3 tools/build_ui_icons.py <clone of game-icons/icons>`.", "",
        "| In-game name | game-icons.net name | Author |", "|---|---|---|",
    ]
    lines += ["| %s | %s | %s |" % row for row in credits]
    with open(os.path.join(out_dir, "..", "ICON_CREDITS.md"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print("wrote %d icons" % len(credits))
    return 0


if __name__ == "__main__":
    sys.exit(main())
