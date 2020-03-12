// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.repeat;

import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * WordRepeatError
 *
 * @brief
 * Repeats a word. The longer the word the less likely such a repetition.
 */
class WordRepeatError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], false) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW])) {
      dstring sToken = cSent.tokens[rW].dup;

      // Add the same word at the next position
      cSent.addTokenAfter(rW, sToken, cSent.spaces[rW], ErrorTypes.REPEAT, MarkTypes.END);
      cSent.spaces[rW] = true; // The previous element will now have a space
      cSent.errors[rW] = ErrorTypes.REPEAT; // Correct the error type
      cSent.setTokenMark(rW, MarkTypes.START);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
}

/**
 * @class
 * CharRepeatError
 *
 * @brief
 * Repeat a single character within a randomly chosen word.
 */
class CharRepeatError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], false) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW])) {
      ulong nPos = NoiserUtility.getRandomPosition(0, cSent.tokens[rW].length - 1, this.mRnd);
      dstring sToken = cSent.tokens[rW].dup;

      // Add the character at position nPos once more
      if (nPos is 0) {
        if (isUpper(sToken[nPos])) {
          cSent.tokens[rW] = to!dstring(sToken[nPos]) ~ toLower(sToken[nPos]) ~ sToken[1..$];
        } else {
          cSent.tokens[rW] = to!dstring(sToken[nPos]) ~ sToken[nPos] ~ sToken[1..$];
        }

      } else if (nPos is (sToken.length - 1)) {
        cSent.tokens[rW] = sToken ~ to!dstring(sToken[nPos]);
      } else {
        cSent.tokens[rW] = sToken[0..nPos] ~ sToken[nPos] ~ sToken[nPos..$];
      }
      if (cSent.tokens[rW] !is sToken) {
        if (NoiserUtility.inLangDict(cSent.tokens[rW], this.mpLanguage.getKeyNeighbourhood()))
          cSent.errors[rW] = ErrorTypes.REAL_WORD;
        else
          cSent.errors[rW] = ErrorTypes.NON_WORD;
      }
      if (cSent.tokens[rW] is cSent.initials[rW]) {
        cSent.errors[rW] = ErrorTypes.NONE;
      }
      cSent.setTokenMark(rW, MarkTypes.SINGLE);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}
