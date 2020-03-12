// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.utility;

import std.algorithm: canFind;
import std.conv;
import std.random;
import std.uni;

import dgenerator.utils.helper : NeighborRepresentation, SentenceRepresentation;
import dgenerator.nlp.language;
import dgenerator.utils.types;

/**
 * @class
 * NoiserUtility
 *
 * @brief
 * Helper structure for all error generator classes.
 */
class NoiserUtility {

  static public bool IsEditable(ErrorTypes nErrorType, bool bFurtherDestruction) {
    if (bFurtherDestruction) {
      return [ErrorTypes.NONE, ErrorTypes.NON_WORD, ErrorTypes.REAL_WORD, ErrorTypes.PUNCTUATION].canFind(nErrorType);
    }

    return (nErrorType == ErrorTypes.NONE);
  }

  static public bool isHyphenationEditable(ErrorTypes nErrorType) {
    return [ErrorTypes.NONE].canFind(nErrorType);
  }

  // DEPRECATED
  static public bool IsEditablePunctionation(dstring sWord) {
    /// TODO(naetherm): Implement me!
    if (sWord.length > 0) return isPunctuation(sWord[0]);
    else return false;
  }

  static public bool isPunctuationOnly(dstring sToken) {
    // Because we extract punctuation character as single units check whether
    // length is correct and the first and only element is of punctuation
    if (sToken.length == 1) return isPunctuation(sToken[0]);

    return false;
  }

  static public bool isAlphaNumeric(dstring sWord) {
    foreach (c; sWord) {
      if (!isAlphaNum(c)) {
        return false;
      }
    }
    return true;
  }

  static public ulong[] getCommaPosiions(ref SentenceRepresentation cSent) {
    ulong[] result;

    for (ulong i = 0; i < cSent.getNumCurrentTokens(); ++i) {
      if (cSent.tokens[i] == ",") {
        result ~= i;
      }
    }

    return result;
  }

  /**
   * @brief
   * Returns true if the full string @p sToken is a number, otherwise false will be returned.
   */
  static public bool isNumeric(ref dstring sWord) {
    foreach (c; sWord) {
      if (!isNumber(c)) {
        return false;
      }
    }
    return true;
  }

  static public bool correctMinLength(dstring sToken, ulong nMinLen) {
    return (sToken.length >= nMinLen);
  }

  static public bool correctMaxLength(dstring sToken, ulong nMaxLen) {
    return (sToken.length <= nMaxLen);
  }

  static public ulong getRandomPosition(ulong nRndMinRange, ulong nRndMaxRange, ref Random nRnd) {
    return uniform!"[]"(nRndMinRange, nRndMaxRange, nRnd);
  }

  static public dchar GetRandomChar(ref Random nRnd) {
    import std.ascii;
    immutable dstring array = to!dstring(lowercase ~ uppercase);
    return array[uniform(0, $, nRnd)];
  }

  static public bool inLangDict(dstring sToken, ref NeighborRepresentation[dstring] key2N) {
    if (sToken in key2N) {
      return true;
    }

    return false;
  }

  static public bool isCapitalized(ref dstring sToken) {
    return (NoiserUtility.isCurrentCharUpper(sToken, 0));
  }

  static public bool isWrongPronoun(ref Language refLanguage, dstring sOriginalPronoun, dstring sSubstitution) {
    if (sOriginalPronoun in refLanguage.getPronounsTable()) {
      if (refLanguage.getPronounTableByKey(sOriginalPronoun).getWrongPronouns().canFind(sSubstitution)) {
        return true;
      }
    }

    return false;
  }

  static public bool isLeftNeighbourLower(ref dstring sToken, ulong nPosition) {
    if ((nPosition-1) > 0) {
      return isLower(sToken[nPosition-1]);
    } else {
      return false;
    }
  }

  static public bool isRightNeighbourLower(ref dstring sToken, ulong nPosition) {
    if ((nPosition+1) < sToken.length) {
      return isLower(sToken[nPosition+1]);
    } else {
      return false;
    }
  }

  /**
   * @brief
   * Helper method checking whether the surrounding characters of a token are lower case or uper case.
   * If just one is an upper case false will be returned.
   *
   */
  static public bool areNeighbouringCharsLower(ref dstring sToken, ulong nPosition) {
    bool bLeft;
    bool bRight;

    if ((nPosition-1) > 0) {
      bLeft = isLower(sToken[nPosition-1]);
    } else {
      bLeft = true;
    }

    if ((nPosition+1) < sToken.length) {
      bRight = isLower(sToken[nPosition+1]);
    } else {
      bRight = true;
    }

    return bLeft && bRight;
  }

  static public bool isAllUpper(ref dstring sToken) {
    foreach (c; sToken) {
      if (isLower(c)) {
        return false;
      }
    }
    return true;
  }

  static public bool isAllLower(ref dstring sToken) {
    foreach (c; sToken) {
      if (isUpper(c)) {
        return false;
      }
    }
    return true;
  }

  /**
   * @brief
   * Checks and returns whether the character at the position @p nPosition is lower case.
   * Returns true if the character is lower case, otherwise false.
   */
  static public bool isCurrentCharLower(ref dstring sToken, ulong nPosition) {
    return isLower(sToken[nPosition]);
  }

  static public bool isCurrentCharUpper(ref dstring sToken, ulong nPosition) {
    return isUpper(sToken[nPosition]);
  }

  /**
   * @brief
   * Returns the logic punctuation group the punctuation within @p sToken belongs to.
   *
   * There are four groups responsible for brackets, marks, punctuation, and others (like |#$%,etc)
   */
  static public dstring getLogicPunctuationGroup(ref dstring sToken) {
    static dstring brackets = "()[]{}<>";
    static dstring marks = "\"\'`´";
    static dstring punctuation = ",;.:!?";
    static dstring others = "\\/|~+-*#§$%&=^_";

    if (brackets.canFind(sToken[0])) {
      return brackets;
    }
    if (marks.canFind(sToken[0])) {
      return marks;
    }
    if (punctuation.canFind(sToken[0])) {
      return punctuation;
    }
    if (others.canFind(sToken[0])) {
      return others;
    }

    return punctuation;
  }



  /**
   * The used random seed.
   */
  static private Random mRnd;
}
