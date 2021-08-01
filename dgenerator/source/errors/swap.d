// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.swap;

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
 * CharSwapError
 *
 * @brief
 * Swaps two characters at a randomized position within the word.
 */
class CharSwapError : ErrorInterface {

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
        NoiserUtility.correctMinLength(cSent.tokens[rW], 3)) {
      ulong nPos = NoiserUtility.getRandomPosition(1, cSent.tokens[rW].length - 2, this.mRnd);

      dstring rToken = cSent.tokens[rW].dup;

      // Take care if the first two letters should be swapped
      if (nPos == 1) {
        // If the first to letter should be swapped AND the first letter is upper
        // case we also have to swap the caseness of the letters
        if (NoiserUtility.isAllUpper(rToken)) {
          cSent.tokens[rW] = rToken[0..nPos-1] ~ rToken[nPos] ~ rToken[nPos-1] ~ rToken[nPos+1..$];
        } else if (NoiserUtility.isCurrentCharUpper(rToken, 0)) {
          cSent.tokens[rW] = rToken[0..nPos-1] ~ toUpper(rToken[nPos]) ~ toLower(rToken[nPos-1]) ~ rToken[nPos+1..$];
        } else {
          cSent.tokens[rW] = rToken[0..nPos-1] ~ toLower(rToken[nPos]) ~ toLower(rToken[nPos-1]) ~ rToken[nPos+1..$];
        }
      } else {
        cSent.tokens[rW] = rToken[0..nPos-1] ~ rToken[nPos] ~ rToken[nPos-1] ~ rToken[nPos+1..$];
      }


      if (cSent.tokens[rW] !is rToken) {
        if (NoiserUtility.isWrongPronoun(this.mpLanguage, rToken, cSent.tokens[rW])) {
          cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
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
