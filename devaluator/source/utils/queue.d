// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.queue;
 
import std.traits: hasIndirections;

/** 
 * @class
 * GrowableCircularQueue
 *
 * @brief
 * Simple but fast implementation of a queue with minimal memory allocation overhead.
 */
class GrowableCircularQueue(TType) {
  public size_t length;
  private size_t first, last;
  private TType[] A = [TType.init];

  public this(TType[] items...) pure nothrow @safe {
    foreach (x; items)
      push(x);
  }

  @property bool empty() const pure nothrow @safe @nogc {
    return length == 0;
  }

  @property TType front() pure nothrow @safe @nogc {
    assert(length != 0);
    return A[first];
  }

  TType opIndex(in size_t i) pure nothrow @safe @nogc {
    assert(i < length);
    return A[(first + i) & (A.length - 1)];
  }

  void push(TType item) pure nothrow @safe {
    if (length >= A.length) { // Double the queue.
      immutable oldALen = A.length;
      A.length *= 2;
      if (last < first) {
        A[oldALen .. oldALen + last + 1] = A[0 .. last + 1];
        static if (hasIndirections!TType)
          A[0 .. last + 1] = TType.init; // Help for the GC.
        last += oldALen;
      }
    }
    last = (last + 1) & (A.length - 1);
    A[last] = item;
    length++;
  }

  @property TType pop() pure nothrow @safe @nogc {
    assert(length != 0);
    auto saved = A[first];
    static if (hasIndirections!TType)
      A[first] = TType.init; // Help for the GC.
    first = (first + 1) & (A.length - 1);
    length--;
    return saved;
  }
}