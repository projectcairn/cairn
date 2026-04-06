#!/usr/bin/env python3
"""Generate static HTML pages for the UK Radio Reference ZIM file.

Reads JSON data from content/zim-builder/data/ and produces a self-contained
set of HTML pages with inline CSS matching Cairn's dark theme.
Output directory: content/zim-builder/output/radio-html/
"""

import json
import os
import struct
import sys
import zlib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
OUT_DIR = os.path.join(SCRIPT_DIR, "output", "radio-html")

DARK_CSS = """
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #1a1a2e; color: #eee; line-height: 1.6; padding: 16px;
}
h1 { color: #e2b714; font-size: 1.5rem; margin-bottom: 8px; }
h2 { color: #e2b714; font-size: 1.2rem; margin: 20px 0 8px; }
p, li { font-size: 0.9rem; color: #ccc; }
a { color: #e2b714; text-decoration: none; }
a:hover { text-decoration: underline; }
nav { background: #16213e; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
nav a { margin-right: 14px; font-size: 0.85rem; }
table {
    width: 100%; border-collapse: collapse; margin: 12px 0;
    background: #16213e; border-radius: 8px; overflow: hidden;
}
th { background: #0f3460; color: #e2b714; text-align: left; padding: 8px 10px; font-size: 0.8rem; }
td { padding: 7px 10px; border-top: 1px solid rgba(255,255,255,0.06); font-size: 0.85rem; }
tr:hover td { background: rgba(255,255,255,0.03); }
.tag { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; }
.tag-analogue { background: #4ecca3; color: #111; }
.tag-digital { background: #3a86ff; color: #fff; }
.tag-ctcss { background: #e2b714; color: #111; }
.warn-box {
    background: rgba(231,76,60,0.12); border: 1px solid #e74c3c;
    border-radius: 8px; padding: 12px; margin: 12px 0; font-size: 0.85rem;
}
.info-box {
    background: rgba(78,204,163,0.1); border: 1px solid #4ecca3;
    border-radius: 8px; padding: 12px; margin: 12px 0; font-size: 0.85rem;
}
.grid-2 {
    display: grid; grid-template-columns: 1fr 1fr; gap: 4px 24px;
    background: #16213e; padding: 12px; border-radius: 8px; margin: 12px 0;
}
.grid-2 span { font-size: 0.85rem; padding: 3px 0; }
.grid-2 .letter { color: #e2b714; font-weight: 700; }
footer { margin-top: 24px; padding-top: 12px; border-top: 1px solid rgba(255,255,255,0.06); font-size: 0.75rem; color: #888; }
"""

NAV_LINKS = [
    ("index.html", "Home"),
    ("pmr446.html", "PMR446"),
    ("emergency.html", "Emergency"),
    ("amateur.html", "Amateur"),
    ("marine.html", "Marine VHF"),
    ("meshtastic.html", "Meshtastic"),
    ("phonetic.html", "Phonetic"),
]

NATO_ALPHABET = [
    ("A", "Alpha"), ("B", "Bravo"), ("C", "Charlie"), ("D", "Delta"),
    ("E", "Echo"), ("F", "Foxtrot"), ("G", "Golf"), ("H", "Hotel"),
    ("I", "India"), ("J", "Juliet"), ("K", "Kilo"), ("L", "Lima"),
    ("M", "Mike"), ("N", "November"), ("O", "Oscar"), ("P", "Papa"),
    ("Q", "Quebec"), ("R", "Romeo"), ("S", "Sierra"), ("T", "Tango"),
    ("U", "Uniform"), ("V", "Victor"), ("W", "Whiskey"), ("X", "X-ray"),
    ("Y", "Yankee"), ("Z", "Zulu"),
]

UK_BAND_PLAN = [
    ("160m", "1.810–2.000 MHz", "LSB / CW / Digital", "Night-time propagation, NVIS"),
    ("80m", "3.500–3.800 MHz", "LSB / CW / Digital", "Primary UK HF, NVIS day/night"),
    ("60m", "5.354–5.358 MHz", "USB (channelised)", "Secondary, WRC-15 allocation"),
    ("40m", "7.000–7.200 MHz", "LSB / CW / Digital", "Excellent medium-range, day/night"),
    ("30m", "10.100–10.150 MHz", "CW / Digital only", "Digital modes popular"),
    ("20m", "14.000–14.350 MHz", "USB / CW / Digital", "Primary DX band, daytime"),
    ("17m", "18.068–18.168 MHz", "USB / CW / Digital", "DX, daytime propagation"),
    ("15m", "21.000–21.450 MHz", "USB / CW / Digital", "DX, sunspot-dependent"),
    ("12m", "24.890–24.990 MHz", "USB / CW / Digital", "DX, solar cycle peak"),
    ("10m", "28.000–29.700 MHz", "USB / FM / CW", "DX or local, solar dependent"),
    ("6m", "50.000–52.000 MHz", "USB / FM / CW", "Sporadic-E propagation"),
    ("2m", "144.000–146.000 MHz", "FM / SSB / Digital", "Primary VHF, repeaters, calling 145.500"),
    ("70cm", "430.000–440.000 MHz", "FM / SSB / Digital", "UHF, repeaters, calling 433.500"),
    ("23cm", "1240.000–1325.000 MHz", "FM / ATV / Digital", "Microwave, line-of-sight"),
]


def load_json(filename):
    path = os.path.join(DATA_DIR, filename)
    with open(path, "r") as f:
        return json.load(f)


def page(title, body, current=""):
    links = []
    for href, label in NAV_LINKS:
        style = ' style="text-decoration:underline"' if href == current else ""
        links.append(f'<a href="{href}"{style}>{label}</a>')
    nav = "\n".join(links)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Cairn Radio Reference</title>
<style>{DARK_CSS}</style>
</head>
<body>
<nav>{nav}</nav>
<h1>{title}</h1>
{body}
<footer>Cairn Radio Reference · Project Cairn · Offline use</footer>
</body>
</html>"""


def mode_tag(mode):
    m = mode.lower()
    if "ctcss" in m:
        return f'<span class="tag tag-ctcss">{mode}</span>'
    elif "digital" in m:
        return f'<span class="tag tag-digital">{mode}</span>'
    return f'<span class="tag tag-analogue">{mode}</span>'


def build_index():
    body = """
<p>Quick-reference radio information for the UK. All content works offline.</p>
<h2>Sections</h2>
<ul style="list-style:none;padding:0">
<li style="margin:8px 0">📻 <a href="pmr446.html">PMR446 Channels</a> — All 48 licence-free channels</li>
<li style="margin:8px 0">🚨 <a href="emergency.html">Emergency Frequencies</a> — 999, Coastguard, distress</li>
<li style="margin:8px 0">📡 <a href="amateur.html">Amateur Radio</a> — UK band plan summary</li>
<li style="margin:8px 0">⚓ <a href="marine.html">Marine VHF</a> — Key marine channels</li>
<li style="margin:8px 0">📶 <a href="meshtastic.html">Meshtastic / LoRa</a> — Off-grid mesh networking</li>
<li style="margin:8px 0">🔤 <a href="phonetic.html">NATO Phonetic Alphabet</a> — Alpha to Zulu</li>
</ul>
<div class="info-box">
<strong>No licence required</strong> for PMR446 and Meshtastic/LoRa (ISM band).
Amateur radio requires a valid UK amateur radio licence from Ofcom (Foundation, Intermediate or Full).
Marine VHF requires a Short Range Certificate (SRC) for non-distress use.
</div>"""
    return page("UK Radio Reference", body, "index.html")


def build_pmr446():
    channels = load_json("pmr446-channels.json")
    rows = "\n".join(
        f"<tr><td>{c['channel']}</td><td>{c['frequency_mhz']:.5f}</td><td>{mode_tag(c['mode'])}</td></tr>"
        for c in channels
    )
    body = f"""
<p>PMR446 is a licence-free UHF radio service available across Europe.
Max power 500 mW ERP, integral antenna only.</p>
<div class="info-box">Channels 1–8: Analogue (12.5 kHz) · Channels 9–16: Digital (12.5 kHz) ·
Channels 17–32: Analogue with CTCSS sub-tones · Channels 33–48: Digital (extended)</div>
<table>
<thead><tr><th>Ch</th><th>Frequency (MHz)</th><th>Mode</th></tr></thead>
<tbody>{rows}</tbody>
</table>
<div class="warn-box">PMR446 is shared spectrum. Anyone can listen. Do not transmit sensitive information.</div>"""
    return page("PMR446 Channels", body, "pmr446.html")


def build_emergency():
    freqs = load_json("emergency-frequencies.json")
    rows = "\n".join(
        f"<tr><td>{f['service']}</td><td><strong>{f['frequency']}</strong>"
        + (f" ({f['channel']})" if "channel" in f else "")
        + f"</td><td>{f.get('mode', '')}</td><td>{f['notes']}</td></tr>"
        for f in freqs
    )
    body = f"""
<div class="warn-box"><strong>In a life-threatening emergency, always dial 999 or 112 first.</strong>
If you have any mobile signal at all, a phone call is faster and more reliable than radio.</div>
<table>
<thead><tr><th>Service</th><th>Frequency</th><th>Mode</th><th>Notes</th></tr></thead>
<tbody>{rows}</tbody>
</table>
<h2>MAYDAY Procedure (Voice)</h2>
<p>1. "MAYDAY, MAYDAY, MAYDAY" · 2. "This is [your callsign/vessel name] × 3" ·
3. "MAYDAY [callsign]" · 4. Position · 5. Nature of distress · 6. Assistance required ·
7. Number of persons · 8. "Over"</p>"""
    return page("Emergency Frequencies", body, "emergency.html")


def build_amateur():
    rows = "\n".join(
        f"<tr><td><strong>{b[0]}</strong></td><td>{b[1]}</td><td>{b[2]}</td><td>{b[3]}</td></tr>"
        for b in UK_BAND_PLAN
    )
    body = f"""
<p>Summary of UK amateur radio band allocations. Full details at
<a href="https://rsgb.org/main/operating/band-plans/">RSGB Band Plans</a>.</p>
<div class="warn-box">A valid Ofcom amateur radio licence is required to transmit.
Foundation licence holders are limited to 10 W on most bands.</div>
<table>
<thead><tr><th>Band</th><th>Range</th><th>Modes</th><th>Notes</th></tr></thead>
<tbody>{rows}</tbody>
</table>
<h2>Key Calling Frequencies</h2>
<table>
<thead><tr><th>Band</th><th>Frequency</th><th>Mode</th></tr></thead>
<tbody>
<tr><td>2m</td><td>145.500 MHz</td><td>FM</td></tr>
<tr><td>70cm</td><td>433.500 MHz</td><td>FM</td></tr>
<tr><td>2m SSB</td><td>144.300 MHz</td><td>USB</td></tr>
<tr><td>HF 40m</td><td>7.090 MHz</td><td>LSB</td></tr>
</tbody>
</table>"""
    return page("Amateur Radio — UK Band Plan", body, "amateur.html")


def build_marine():
    channels = load_json("marine-vhf.json")
    rows = "\n".join(
        f"<tr><td><strong>Ch {c['channel']}</strong></td><td>{c['frequency_mhz']:.3f} MHz</td>"
        f"<td>{c['designation']}</td><td>{c['notes']}</td></tr>"
        for c in channels
    )
    body = f"""
<p>Key marine VHF channels for UK waters. A Short Range Certificate (SRC) is required
to operate marine VHF radio, except for distress calls.</p>
<table>
<thead><tr><th>Channel</th><th>Frequency</th><th>Designation</th><th>Notes</th></tr></thead>
<tbody>{rows}</tbody>
</table>
<div class="warn-box">Channel 16 (156.800 MHz) must be monitored at all times when at sea.
False distress calls are a criminal offence under the Wireless Telegraphy Act 2006.</div>
<h2>DSC (Digital Selective Calling)</h2>
<p>Modern VHF radios with DSC can send automated distress alerts on Ch 70 (156.525 MHz)
at the press of a button. Ensure your MMSI number is correctly programmed.</p>"""
    return page("Marine VHF Channels", body, "marine.html")


def build_meshtastic():
    body = """
<p>Meshtastic is an open-source, long-range mesh networking platform using LoRa radios.
No licence is required in the UK when using the ISM band at permitted power levels.</p>
<h2>UK Legal Parameters</h2>
<table>
<thead><tr><th>Parameter</th><th>Value</th></tr></thead>
<tbody>
<tr><td>Band</td><td>869.4–869.65 MHz (ISM)</td></tr>
<tr><td>Max power</td><td>≤ 500 mW ERP (≤ 25 mW for some sub-bands)</td></tr>
<tr><td>Duty cycle</td><td>≤ 10%</td></tr>
<tr><td>Licence</td><td>None required</td></tr>
<tr><td>Default channel</td><td>LongFast (868.0 MHz, SF12, BW 125 kHz)</td></tr>
</tbody>
</table>
<h2>Range Expectations</h2>
<table>
<thead><tr><th>Terrain</th><th>Typical Range</th></tr></thead>
<tbody>
<tr><td>Urban / dense buildings</td><td>0.5–2 km</td></tr>
<tr><td>Suburban / light cover</td><td>2–5 km</td></tr>
<tr><td>Open countryside</td><td>5–15 km</td></tr>
<tr><td>Hilltop / line-of-sight</td><td>15–50+ km</td></tr>
</tbody>
</table>
<div class="info-box"><strong>Tip:</strong> Elevation is everything. A node at 10 m height can
reach further than a node at ground level with twice the power. Use rooftop or
window-mounted nodes with external antennas for best results.</div>
<h2>Recommended Hardware</h2>
<ul style="margin:8px 0 8px 20px">
<li>Heltec LoRa 32 V3 (budget, good for fixed nodes)</li>
<li>LilyGo T-Beam (GPS built-in, good for portable)</li>
<li>RAK WisBlock (modular, weatherproof enclosures available)</li>
</ul>
<p>Firmware and setup: <a href="https://meshtastic.org">meshtastic.org</a></p>"""
    return page("Meshtastic / LoRa Mesh", body, "meshtastic.html")


def build_phonetic():
    items = "\n".join(
        f'<span class="letter">{letter}</span><span>{word}</span>'
        for letter, word in NATO_ALPHABET
    )
    body = f"""
<p>The NATO phonetic alphabet is used to spell out letters clearly over radio.
Use it whenever spelling callsigns, grid references, or critical words.</p>
<div class="grid-2">{items}</div>
<h2>Numerals</h2>
<div class="grid-2">
<span class="letter">0</span><span>Zero</span>
<span class="letter">1</span><span>Wun</span>
<span class="letter">2</span><span>Too</span>
<span class="letter">3</span><span>Tree</span>
<span class="letter">4</span><span>Fow-er</span>
<span class="letter">5</span><span>Fife</span>
<span class="letter">6</span><span>Six</span>
<span class="letter">7</span><span>Sev-en</span>
<span class="letter">8</span><span>Ait</span>
<span class="letter">9</span><span>Nin-er</span>
</div>
<h2>Pro-words</h2>
<table>
<thead><tr><th>Word</th><th>Meaning</th></tr></thead>
<tbody>
<tr><td><strong>Roger</strong></td><td>Message received and understood</td></tr>
<tr><td><strong>Wilco</strong></td><td>Will comply (implies Roger)</td></tr>
<tr><td><strong>Over</strong></td><td>End of transmission, expecting reply</td></tr>
<tr><td><strong>Out</strong></td><td>End of transmission, no reply expected</td></tr>
<tr><td><strong>Say Again</strong></td><td>Please repeat your last message</td></tr>
<tr><td><strong>Copy</strong></td><td>I heard your message (informal)</td></tr>
<tr><td><strong>Break</strong></td><td>Pause in transmission / interruption</td></tr>
<tr><td><strong>Radio Check</strong></td><td>How do you read me?</td></tr>
</tbody>
</table>"""
    return page("NATO Phonetic Alphabet", body, "phonetic.html")


def generate_favicon(path, size=48, color=(0xE2, 0xB7, 0x14)):
    """Write a minimal solid-color PNG using only struct + zlib."""
    r, g, b = color
    raw_rows = b""
    for _ in range(size):
        raw_rows += b"\x00" + bytes([r, g, b]) * size
    compressed = zlib.compress(raw_rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    ihdr_data = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr_data))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    pages = {
        "index.html": build_index,
        "pmr446.html": build_pmr446,
        "emergency.html": build_emergency,
        "amateur.html": build_amateur,
        "marine.html": build_marine,
        "meshtastic.html": build_meshtastic,
        "phonetic.html": build_phonetic,
    }

    for filename, builder in pages.items():
        path = os.path.join(OUT_DIR, filename)
        with open(path, "w") as f:
            f.write(builder())
        print(f"  wrote {filename}")

    generate_favicon(os.path.join(OUT_DIR, "favicon.png"))
    print("  wrote favicon.png")
    print(f"\n{len(pages)} pages + favicon generated in {OUT_DIR}")


if __name__ == "__main__":
    main()
