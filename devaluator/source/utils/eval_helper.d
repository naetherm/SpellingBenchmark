// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.eval_helper;

import std.algorithm: canFind, max, min;
import std.conv;
import std.math;
import std.random;
import std.uni;
import std.algorithm.mutation;
import devaluator.utils.nlp: jaroSimilarity, jwSimilarity;
import std.algorithm.comparison: levenshteinDistance;

class EvalHelper {

  static public bool IsEditablePunctionation(dstring sWord) {
    /// TODO(naetherm): Implement me!
    if (sWord.length > 0) return isPunctuation(sWord[0]);
    else return false;
  }

  static public auto sim(dstring w1, dstring w2, bool bReverse = false) {
    if (bReverse) {
      return 0.5 * (jwSimilarity(w1.dup.reverse, w2.dup.reverse) + (1.0 - to!float(levenshteinDistance(w1, w2))/max(w1.length, w2.length)));
    } else {
      return 0.5 * (jwSimilarity(w1, w2) + (1.0 - to!float(levenshteinDistance(w1, w2))/max(w1.length, w2.length)));
    }
  }
}