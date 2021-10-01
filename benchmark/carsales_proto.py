#!/usr/bin/env python

import carsales_pb2
from common import rand_int, rand_double, rand_bool, from_bytes_helper
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
    car.color = rand_int(len(COLORS))

    car.seats = 2 + rand_int(6)
    car.doors = 2 + rand_int(3)

    for _ in range(4):
        wheel = car.wheel.add()
        wheel.diameter = 25 + rand_int(15)
        wheel.air_pressure = 30 + rand_double(20)
        wheel.snow_tires = rand_int(16) == 0

    car.length = 170 + rand_int(150)
    car.width = 48 + rand_int(36)
    car.height = 54 + rand_int(48)
    car.weight = car.length * car.width * car.height // 200

    engine = car.engine
    engine.horsepower = 100 * rand_int(400)
    engine.cylinders = 4 + 2 * rand_int(3)
    engine.cc = 800 + rand_int(10000)
    engine.uses_gas = True
    engine.uses_electric = rand_bool()

    car.fuel_capacity = 10.0 + rand_double(30.0)
    car.fuel_level = rand_double(car.fuel_capacity)
    car.has_power_windows = rand_bool()
    car.has_power_steering = rand_bool()
    car.has_cruise_control = rand_bool()
    car.cup_holders = rand_int(12)
    car.has_nav_system = rand_bool()


def calc_value(car):
    result = 0

    result += car.seats * 200
    result += car.doors * 350
    for wheel in car.wheel:
        result += wheel.diameter * wheel.diameter
        result += 100 if wheel.snow_tires else 0

    result += car.length * car.width * car.height // 50

    engine = car.engine
    result += engine.horsepower * 40
    if engine.uses_electric:
        if engine.uses_gas:
            result += 5000
        else:
            result += 3000

    result += 100 if car.has_power_windows else 0
    result += 200 if car.has_power_steering else 0
    result += 400 if car.has_cruise_control else 0
    result += 2000 if car.has_nav_system else 0

    result += car.cup_holders * 25

    return result


class Benchmark:
    def __init__(self, compression):
        self.Request = carsales_pb2.ParkingLot
        self.Response = carsales_pb2.TotalValue
        self.from_bytes_request = from_bytes_helper(carsales_pb2.ParkingLot)
        self.from_bytes_response = from_bytes_helper(carsales_pb2.TotalValue)
        self.to_bytes = lambda x: x.SerializeToString()

    def setup(self, request):
        result = 0
        for _ in range(rand_int(200)):
            car = request.car.add()
            random_car(car)
            result += calc_value(car)
        return result

    def handle(self, request, response):
        result = 0
        for car in request.car:
            result += calc_value(car)

        response.amount = result

    def check(self, response, expected):
        return response.amount == expected
