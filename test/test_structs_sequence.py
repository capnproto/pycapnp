import os

import pytest

import capnp

this_dir = os.path.dirname(__file__)


@pytest.fixture
def message_schemas():
    return capnp.load(os.path.join(this_dir, "test_structs_sequence.capnp"))


@pytest.fixture
def make_apple(message_schemas):
    def _make_apple(color: str):
        apple = message_schemas.Apple.new_message()
        apple.fruitId = message_schemas.FruitId.apple
        apple.color = color
        return apple

    return _make_apple


@pytest.fixture
def red_apple(make_apple):
    return make_apple("Red")


@pytest.fixture
def green_apple(make_apple):
    return make_apple("Green")


@pytest.fixture
def banana(message_schemas):
    banana_ = message_schemas.Banana.new_message()
    banana_.fruitId = message_schemas.FruitId.banana
    banana_.length = 12.345
    return banana_


@pytest.fixture
def cherry(message_schemas):
    cherry_ = message_schemas.Cherry.new_message()
    cherry_.fruitId = message_schemas.FruitId.cherry
    cherry_.sweetness = 64
    return cherry_


@pytest.fixture
def fruit_basket(cherry, red_apple, banana, green_apple):
    return [cherry, red_apple, banana, green_apple]


@pytest.fixture
def fruit_basket_encoded(fruit_basket):
    return b"".join(fruit.to_bytes_packed() for fruit in fruit_basket)


@pytest.fixture
def expected(fruit_basket):
    return [fruit.to_dict() for fruit in fruit_basket]


def test_parse_structs_sequence(message_schemas, fruit_basket_encoded, expected):
    # ARRANGE
    reader = capnp.read_multiple_bytes_packed(fruit_basket_encoded)

    def _parse_fruit(any_):
        unknown_fruit = any_.as_struct(message_schemas.UnknownFruit)
        if unknown_fruit.fruitId == message_schemas.FruitId.apple:
            return any_.as_struct(message_schemas.Apple)

        if unknown_fruit.fruitId == message_schemas.FruitId.banana:
            return any_.as_struct(message_schemas.Banana)

        if unknown_fruit.fruitId == message_schemas.FruitId.cherry:
            return any_.as_struct(message_schemas.Cherry)

        return unknown_fruit

    # ACT
    parsed = [_parse_fruit(any_).to_dict() for any_ in reader]

    # ASSERT
    assert parsed == expected


def test_empty_sequence():
    reader = capnp.read_multiple_bytes_packed(b"")
    assert len(list(reader)) == 0
