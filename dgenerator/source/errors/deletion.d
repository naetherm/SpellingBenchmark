// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.deletion;

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
 * CharDeleteError
 *
 * @brief
 * Randomly deletes a character of the token.
 */
class CharDeleteError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
       !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
       NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      // Get a random position within the selected token
      ulong nPos = NoiserUtility.getRandomPosition(0, cSent.tokens[rW].length - 1, this.mRnd);

      // Copy that token
      dstring rToken = cSent.tokens[rW].dup;

      ulong nLen = rToken.length;

      if (nPos is 0) {
        cSent.tokens[rW] = rToken[1..$];
      } else if (nPos is (nLen - 1)) {
        cSent.tokens[rW] = rToken[0..nLen-1];
      } else {
        cSent.tokens[rW] = rToken[0..nPos] ~ rToken[nPos+1..$];
      }
      if (cSent.tokens[rW] !is rToken) {
        if (NoiserUtility.isWrongPronoun(this.mpLanguage, cSent.tokens[rW], rToken)) {
          cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
        }
        // If we remove a hyphen make this a COMPOUND_HYPHEN error
        else if (rToken[nPos] == '-') {
          cSent.errors[rW] = ErrorTypes.COMPOUND_HYPHEN;
        }
        else if (NoiserUtility.inLangDict(cSent.tokens[rW], this.mpLanguage.getKeyNeighbourhood()))
          cSent.errors[rW] = ErrorTypes.REAL_WORD;
        else
          cSent.errors[rW] = ErrorTypes.NON_WORD;
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

class DoubleCharDeleteError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
       !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
       bFurtherDestruction &&
       NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      // Get a random position within the selected token
      ulong nPos = NoiserUtility.getRandomPosition(0, cSent.tokens[rW].length - 1, this.mRnd);

      // Copy that token
      dstring rToken = cSent.tokens[rW].dup;

      ulong nLen = rToken.length;

      if (nPos is 0) {
        cSent.tokens[rW] = rToken[1..$];
      } else if (nPos is (nLen - 1)) {
        cSent.tokens[rW] = rToken[0..nLen-1];
      } else {
        cSent.tokens[rW] = rToken[0..nPos] ~ rToken[nPos+1..$];
      }
      if (cSent.tokens[rW] !is rToken) {
        if (NoiserUtility.isWrongPronoun(this.mpLanguage, cSent.tokens[rW], rToken)) {
          cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
        }
        // If we remove a hyphen make this a COMPOUND_HYPHEN error
        else if (rToken[nPos] == '-') {
          cSent.errors[rW] = ErrorTypes.COMPOUND_HYPHEN;
        }
        else if (NoiserUtility.inLangDict(cSent.tokens[rW], this.mpLanguage.getKeyNeighbourhood()))
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
