// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.correlation_helper;

import std.algorithm;
import std.conv;
import std.math;
import std.string;

import devaluator.utils.language: Language;

class CorrelationHelper {

  static bool isCapitalisationError(dstring sSrc, dstring sCorr, dstring sPrd) {
    import std.uni;
     if (sPrd.length >= 1 && sSrc.length >= 1) {
      if (isLower(sPrd[0])) {
        if (sPrd.length > 1 && sSrc.length > 1) {
          return ((toUpper(sPrd[0]) == sSrc[0]) && (sPrd[1..$] == sSrc[1..$]));
        } else {
          return (toUpper(sPrd[0]) == sSrc[0]);
        }
      } else {
        if (sPrd.length > 1 && sSrc.length > 1) {
          return ((toLower(sPrd[0]) == sSrc[0]) && (sPrd[1..$] == sSrc[1..$]));
        } else {
          return (toLower(sPrd[0]) == sSrc[0]);
        }
      }
    }
    return false;
  }

  static bool isCompoundHyphenError(dstring sSrc, dstring sCorr, dstring sPrd) {
    if (sCorr.canFind("-")) {
      return !(sPrd.canFind("-"));
    } else {
      return sPrd.canFind("-");
    }
  }

  static bool isHyphenationError(dstring sSrc, dstring sCorr, dstring sPrd) {
    if (sPrd.canFind("-")) {
      return (to!dstring("-").among(sSrc) == 0) && (cmp(sPrd.filter!(c => c != '-'), sCorr) == 0);
    } else {
      return sCorr.canFind("-");
    }
  }

  static bool isPunctuationError(dstring sSrc, dstring sCorr, dstring sPrd) {
    import std.uni;
    if ((sPrd.length == 1) && (sCorr.length == 1)) {
      return isPunctuation(sCorr[0]);
    }

    return false;
  }

  static bool isRealWordError(dstring sSrc, dstring sCorr, dstring sPrd, ref Language cL) {
    return (cL.isRealWord(sPrd) && cL.isRealWord(sSrc));
  }

  static bool isNonWordError(dstring sSrc, dstring sCorr, dstring sPrd, ref Language cL) {
    return (!cL.isRealWord(sPrd) && !cL.isArchaicWord(sPrd));
  }

  static bool isArchaicWordError(dstring sSrc, dstring sCorr, dstring sPrd, ref Language cL) {
    return cL.isArchaicWord(sPrd);
  }

  static bool isPersonalPronounError(dstring sSrc, dstring sCorr, dstring sPrd, ref Language cL) {
    if (sSrc in cL.getPronounsTable() || sCorr in cL.getPronounsTable()) {
      return true;
    }
    return false;
  }

  static bool isTenseError(dstring sSrc, dstring sCorr, dstring sPrd, ref Language cL) {
    // TODO(naetherm): Implement me!
    return false;
  }
}