#!/usr/bin/env python

import json
import requests
from datetime import datetime

# 2026-02-13 Piko: 使用 Nerd Font 线条简约图标 (方案 B)
WEATHER_CODES = {
    '113': '󰖙', # Sunny
    '116': '󰖕', # Partly cloudy
    '119': '󰖐', # Cloudy
    '122': '󰖐', # Overcast
    '143': '󰖑', # Mist
    '176': '󰖗', # Patchy rain
    '179': '󰖗', # Patchy snow
    '182': '󰖗', # Patchy sleet
    '185': '󰖗', # Patchy drizzle
    '200': '󰖓', # Thunder
    '227': '󰖘', # Blowing snow
    '230': '󰖘', # Blizzard
    '248': '󰖑', # Fog
    '260': '󰖑', # Freezing fog
    '263': '󰖗', # Light drizzle
    '266': '󰖗', # Light drizzle
    '281': '󰖗', # Freezing drizzle
    '284': '󰖗', # Heavy freezing drizzle
    '293': '󰖗', # Light rain
    '296': '󰖗', # Light rain
    '299': '󰖖', # Moderate rain
    '302': '󰖖', # Moderate rain
    '305': '󰖖', # Heavy rain
    '308': '󰖖', # Heavy rain
    '311': '󰖖', # Light freezing rain
    '314': '󰖖', # Heavy freezing rain
    '317': '󰖖', # Light sleet
    '320': '󰖖', # Heavy sleet
    '323': '󰖘', # Light snow
    '326': '󰖘', # Light snow
    '329': '󰖘', # Moderate snow
    '332': '󰖘', # Moderate snow
    '335': '󰖘', # Heavy snow
    '338': '󰖘', # Heavy snow
    '350': '󰖖', # Ice pellets
    '353': '󰖗', # Light rain shower
    '356': '󰖖', # Heavy rain shower
    '359': '󰖖', # Torrential rain shower
    '362': '󰖖', # Light sleet shower
    '365': '󰖖', # Heavy sleet shower
    '368': '󰖘', # Light snow shower
    '371': '󰖘', # Heavy snow shower
    '374': '󰖖', # Light ice pellets
    '377': '󰖖', # Heavy ice pellets
    '386': '󰖓', # Light rain with thunder
    '389': '󰖓', # Heavy rain with thunder
    '392': '󰖓', # Light snow with thunder
    '395': '󰖘'  # Heavy snow with thunder
}

data = {}

try:
    weather = requests.get("https://wttr.in/?format=j1", timeout=10).json()
    current = weather['current_condition'][0]
    
    # 组合图标和气温
    icon = WEATHER_CODES.get(current['weatherCode'], '󰖐')
    temp = current['FeelsLikeC'] + "°C"
    
    data['text'] = f"{icon} {temp}"
    data['tooltip'] = f"{current['weatherDesc'][0]['value']} {current['temp_C']}°C"
except Exception as e:
    data['text'] = "󰖐 --°C"

print(json.dumps(data))