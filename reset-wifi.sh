#!/bin/sh

sudo ifconfig wlan0 down

sleep 5

sudo ifconfig wlan0 up
