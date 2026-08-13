#!/usr/bin/env python3
"""Fetch a forecast from Open-Meteo and print it as flat key=value lines.

Usage:  weather.py [lat] [lon] [c|f] [days]

Open-Meteo needs no API key. Empty lat/lon means "figure it out", which we do
via ipinfo.io, the same lookup the public-ip widget already makes, so the
widget shows the right place the moment it is added, with nothing to configure.

Printing key=value keeps the QML side free of JSON parsing; it just splits lines.
Any failure prints nothing and exits 0, so the widget keeps its last good data
instead of flashing an error every time the network hiccups.
"""
import json
import sys
import urllib.request

FORECAST_URL = (
    "https://api.open-meteo.com/v1/forecast"
    "?latitude={lat}&longitude={lon}"
    "&current=temperature_2m,weather_code,is_day"
    "&daily=weather_code,temperature_2m_max,temperature_2m_min"
    "&timezone=auto&forecast_days={days}"
)


def fetch(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "lessplasma-weather-strip"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.load(response)


def locate():
    """(lat, lon, city) from the caller's public IP; empty strings on failure."""
    try:
        data = fetch("https://ipinfo.io/json", timeout=5)
    except Exception:
        return "", "", ""
    loc = data.get("loc", "")
    if "," not in loc:
        return "", "", data.get("city", "")
    lat, lon = loc.split(",")[:2]
    return lat.strip(), lon.strip(), data.get("city", "")


def main():
    argv = sys.argv[1:]
    lat = argv[0].strip() if len(argv) > 0 else ""
    lon = argv[1].strip() if len(argv) > 1 else ""
    unit = (argv[2].strip().lower() if len(argv) > 2 else "c")
    days = argv[3].strip() if len(argv) > 3 else "7"

    city = ""
    if not lat or not lon:
        lat, lon, city = locate()
    if not lat or not lon:
        return 0

    url = FORECAST_URL.format(lat=lat, lon=lon, days=days)
    if unit == "f":
        url += "&temperature_unit=fahrenheit"

    try:
        data = fetch(url)
    except Exception:
        return 0

    out = []
    if city:
        out.append(f"city={city}")

    current = data.get("current", {})
    if "temperature_2m" in current:
        out.append(f"current_temp={round(current['temperature_2m'])}")
    out.append(f"current_code={current.get('weather_code', 0)}")
    out.append(f"is_day={current.get('is_day', 1)}")

    daily = data.get("daily", {})
    times = daily.get("time", []) or []
    codes = daily.get("weather_code", []) or []
    highs = daily.get("temperature_2m_max", []) or []
    lows = daily.get("temperature_2m_min", []) or []

    def at(seq, i, fallback=0):
        return seq[i] if i < len(seq) and seq[i] is not None else fallback

    for i, day in enumerate(times):
        out.append(f"d{i}_date={day}")
        out.append(f"d{i}_code={at(codes, i)}")
        out.append(f"d{i}_max={round(at(highs, i))}")
        out.append(f"d{i}_min={round(at(lows, i))}")

    out.append(f"count={len(times)}")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
