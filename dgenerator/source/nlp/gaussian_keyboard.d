// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.nlp.gaussian_keyboard;

import dgenerator.utils.keyboards;
import std.algorithm.comparison: levenshteinDistance;
import std.algorithm;
import std.container: Array;
import std.math;
import std.string;
import std.typecons;
import std.stdio;


float SHIFT_COST = 3.0;
float INSERTION_COST = 1.0;
float DELETION_COST = 1.0;
float SUBSTITUTION_COST = 1.0;
float TRANSPOSITION_COST = 1.0;

class GaussianKeyboard {

  interface AbstractAction {
    float cost(string s);
    string perform(string s);
  }

  class InsertionAction : AbstractAction {
    this(size_t i, char c) {
      this.i = i;
      this.c = c;
    }
    override float cost(string s) {
      return this.outer.insertionCost(s, this.i, this.c);
    }
    override string perform(string s) {
      return s[0..this.i] ~ this.c ~ s[this.i..$];
    }
    size_t i;
    char c;
  }
  class SubstitutionAction : AbstractAction {
    this(size_t i, char c) {
      this.i = i;
      this.c = c;
    }
    override float cost(string s) {
      return this.outer.substitutionCost(s, this.i, this.c);
    }
    override string perform(string s) {
      return s[0..this.i] ~ this.c ~ s[this.i+1..$];
    }
    size_t i;
    char c;
  }
  class DeletionAction : AbstractAction {
    this(size_t i) {
      this.i = i;
    }
    override float cost(string s) {
      return this.outer.deletionCost(s, this.i);
    }
    override string perform(string s) {
      return s[0..this.i] ~  s[this.i+1..$];
    }
    size_t i;
  }
  class TranspositionAction : AbstractAction {
    this(size_t i, char c) {
      this.i = i;
      this.c = c;
    }
    override float cost(string s) {
      return this.outer.transpositionCost(s, this.i);
    }
    override string perform(string s) {
      return s[0..this.i] ~ s[this.i+1] ~ s[this.i] ~ s[this.i+2..$];
    }
    size_t i;
    char c;
  }

  this(string sLangCode) {
    this.msLangCode = sLangCode;

    if (isQwerty(this.msLangCode)) {
      this.keyboardArray = qwertyKeyboardArray;
      this.shiftedKeyboardArray = qwertyShiftedKeyboardArray;
    } else if (isQwertz(this.msLangCode)) {
      this.keyboardArray = qwertzKeyboardArray;
      this.shiftedKeyboardArray = qwertzShiftedKeyboardArray;
    }
  }

  Array!string generate_typos(string sInput, int nDistance = 1) {
    // Check if we can noise that string at all
    Array!string result;
    if (!this.checkAvailable(sInput)) {
      result.insertBack(sInput);
      return result;
    }
    int t = 0;
    int r = nDistance;
    // Get a list of all actions that can be performed on the current string
    auto actions = this.getPossibleActions(sInput);

    auto c = Array!ulong(actions.length);

    string changedString = sInput.dup;

    outer: while (true) {
      //writeln("c: {}", c[0..$]);
      if (t == 0) {
        // Add the unchanged string
        result.insertBack(sInput);

      } else {
        // Add the performed action
        //writeln("changed: ", actions[c[t]].perform(changedString));
        result.insertBack(actions[c[t]].perform(changedString));

      }
      //writeln(c[t]);
      // Let's try to add a new action
      if ((c[t] > 0) && (r >= actions[0].cost(changedString))) {
        //writeln("t: ", t);
        t += 1;
        c.insertBack(0);
        r -= cast(int)actions[0].cost(changedString);
        changedString = sInput;
        foreach (a; c[1..$]) {
          changedString = actions[a].perform(changedString);
        }
        continue;
      }
      //writeln("out if; t: ", t);

      while (true) {
        //writeln("c2: {}", c[0..$]);
        if (t == 0) {
          break outer;
        }
        size_t i = 1;
        bool bBrokeOut = false;

        while (c[t-1] > (c[t] + i)) {

          if (r >= cast(int)(actions[c[t]+i].cost(changedString) - actions[c[t]].cost(changedString))) {
            c[t] += i;
            r -= cast(int)(actions[c[t]].cost(changedString) - actions[c[t]-i].cost(changedString));
            changedString = sInput;
            foreach (a; c[1..$]) {
              changedString = actions[a].perform(changedString);
            }
            bBrokeOut = true;
            break;
          } else {
            i += 1;
          }
        }

        if (!bBrokeOut) {
          r += cast(int)actions[c[t]].cost(changedString);
          // c.pop(t);
          c.linearRemove(c[t..t]);
          changedString = sInput;

          foreach (a; c[1..$]) {
            changedString = actions[a].perform(changedString);
          }
          t -= 1;
        } else {
          break;
        }
      }
    }

    return result;
  }

  /**
   * @brief
   * Checks if each character in string s is available.
   */
  private bool checkAvailable(string s) {
    foreach (c; s) {
      if (!compareDummy.canFind(c)) {
        return false;
      }
    }
    return true;
  }

  /**
   * @brief
   * Returns a list of possible actions that can be performed on string s.
   */
  private Array!AbstractAction getPossibleActions(string s) {
    Array!AbstractAction actions;

    // Lopp through the input word
    for (size_t i = 0; i < s.length-1; i++) {
      // Generate one delete operation for each character
      actions.insertBack(new DeletionAction(i));
      Array!char sum;
      foreach (r; this.keyboardArray) { foreach (c; r) { sum.insertBack(cast(char)c); } }
      foreach (r; this.shiftedKeyboardArray) { foreach (c; r) { sum.insertBack(cast(char)c); } }
      foreach (c; sum) {
        actions.insertBack(new SubstitutionAction(i, c));
        actions.insertBack(new InsertionAction(i, c));
      }
    }

    return actions;
  }


  ulong typoDistance(string s1, string s2) {
    return levenshteinDistance(s1, s2);
  }

  // arrayForChar
  const(wchar[][]) arrayForChar(char c) {
    for (size_t i = 0; i < this.keyboardArray.length; i++) {
      if (this.keyboardArray[i].canFind(c)) {
        return this.keyboardArray;
      }
    }
    for (size_t i = 0; i < this.shiftedKeyboardArray.length; i++) {
      if (this.shiftedKeyboardArray[i].canFind(c)) {
        return this.shiftedKeyboardArray;
      }
    }
    return this.keyboardArray;
  }

  // getCharacterCoord
  Tuple!(int, int) getCharacterCoord(char ch, const(wchar[][]) keys) {
    int r = -1;
    int c = -1;
    for (size_t i = 0; i < keys.length; i++) {
      for (size_t j = 0; j < keys[i].length; j++) {
        if (keys[i][j] == ch) {

          return tuple(cast(int)i, cast(int)j);
        }
      }
    }
    return tuple(-1, -1);
  }

  float euclideanKeyboardDistance(char c1, char c2) {
    auto d1 = this.getCharacterCoord(c1, this.arrayForChar(c1));
    auto d2 = this.getCharacterCoord(c2, this.arrayForChar(c2));

    return (pow(d1[0] - d2[0], 2) + pow(d1[1] - d2[1], 2));
  }


  float insertionCost(string s, size_t i, char c) {
    if (s.empty || (s.length <= i)) {
      return INSERTION_COST;
    }

    float cost = INSERTION_COST;
    if (this.arrayForChar(s[i]) != this.arrayForChar(c)) {
      cost += SHIFT_COST;
    }
    cost += this.euclideanKeyboardDistance(s[i], c);

    // TODO
    return cost;
  }

  float deletionCost(string s, size_t i) {
    return DELETION_COST;
  }

  float substitutionCost(string s, size_t i, char c) {
    float cost = SUBSTITUTION_COST;
    if ((s.length == 0) || (i >= s.length)) {
      return INSERTION_COST;
    }
    if (this.arrayForChar(s[i]) != this.arrayForChar(c)) {
      cost += SHIFT_COST;
    }
    cost += this.euclideanKeyboardDistance(s[i], c);
    return cost;
  }

  float transpositionCost(string s, size_t i) {
    return TRANSPOSITION_COST;
  }


  const wchar[][] keyboardArray;
  const wchar[][] shiftedKeyboardArray;
  private string msLangCode;
}

unittest {
  import std.stdio;
  writeln("========== GAUSSIAN KEYBOARD ==========");
  GaussianKeyboard gk = new GaussianKeyboard("en_US");

  auto result = gk.generate_typos("test");

  writeln(result[0..$]);
}
