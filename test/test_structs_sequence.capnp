@0x9dafb673e5609df6;


enum FruitId {
  apple @0;
  banana @1;
  cherry @2;
}

struct UnknownFruit {
  fruitId @0: FruitId;
}

struct Apple {
  fruitId @0: FruitId;
  color @1: Text;
}

struct Banana {
  fruitId @0: FruitId;
  length @1: Float32;
}

struct Cherry {
  fruitId @0: FruitId;
  sweetness @1: UInt8;
}
