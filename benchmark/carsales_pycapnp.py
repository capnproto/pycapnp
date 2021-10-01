#!/usr/bin/env python

import capnp
import carsales_capnp
from common import rand_int, rand_double, rand_bool
from random import choice

MAKES = ["Toyota", "GM", "Ford", "Honda", "Tesla"]
MODELS = ["Camry", "Prius", "Volt", "Accord", "Leaf", "Model S"]
COLORS = [
    "black",
    "white",
    "red",
    "green",
    "blue",
    "cyan",
    "magenta",
    "yellow",
    "silver",
]


def random_car(car):
    car.make = choice(MAKES)
    car.model = choice(MODELS)
    car.color = choice(COLORS)

    car.seats = 2 + rand_int(6)
    car.doors = 2 + rand_int(3)

    for wheel in car.init("wheels", 4):
        wheel.diameter = 25 + rand_int(15)
        wheel.airPressure = 30 + rand_double(20)
        wheel.snowTires = rand_int(16) == 0

    car.length = 170 + rand_int(150)
    car.width = 48 + rand_int(36)
    car.height = 54 + rand_int(48)
    car.weight = car.length * car.width * car.height // 200

    engine = car.init("engine")
    engine.horsepower = 100 * rand_int(400)
    engine.cylinders = 4 + 2 * rand_int(3)
    engine.cc = 800 + rand_int(10000)
    engine.usesGas = True
    engine.usesElectric = rand_bool()

    car.fuelCapacity = 10.0 + rand_double(30.0)
    car.fuelLevel = rand_double(car.fuelCapacity)
    car.hasPowerWindows = rand_bool()
    car.hasPowerSteering = rand_bool()
    car.hasCruiseControl = rand_bool()
    car.cupHolders = rand_int(12)
    car.hasNavSystem = rand_bool()


def calc_value(car):
    result = 0

    result += car.seats * 200
    result += car.doors * 350
    for wheel in car.wheels:
        result += wheel.diameter * wheel.diameter
        result += 100 if wheel.snowTires else 0

    result += car.length * car.width * car.height // 50

    engine = car.engine
    result += engine.horsepower * 40
    if engine.usesElectric:
        if engine.usesGas:
            result += 5000
        else:
            result += 3000

    result += 100 if car.hasPowerWindows else 0
    result += 200 if car.hasPowerSteering else 0
    result += 400 if car.hasCruiseControl else 0
    result += 2000 if car.hasNavSystem else 0

    result += car.cupHolders * 25

    return result


class Benchmark:
    def __init__(self, compression):
        self.Request = carsales_capnp.ParkingLot.new_message
        self.Response = carsales_capnp.TotalValue.new_message
        if compression == "packed":
            self.from_bytes_request = carsales_capnp.ParkingLot.from_bytes_packed
            self.from_bytes_response = carsales_capnp.TotalValue.from_bytes_packed
            self.to_bytes = lambda x: x.to_bytes_packed()
        else:
            self.from_bytes_request = carsales_capnp.ParkingLot.from_bytes
            self.from_bytes_response = carsales_capnp.TotalValue.from_bytes
            self.to_bytes = lambda x: x.to_bytes()

    def setup(self, request):
        result = 0
        for car in request.init("cars", rand_int(200)):
            random_car(car)
            result += calc_value(car)
        return result

    def handle(self, request, response):
        result = 0
        for car in request.cars:
            result += calc_value(car)

        response.amount = result

    def check(self, response, expected):
        return response.amount == expected
