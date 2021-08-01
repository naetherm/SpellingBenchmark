// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.gaussian_keyboard;

import std.container: Array;
import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.nlp.gaussian_keyboard: GaussianKeyboard;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * GaussianKeyboardError
 *
 * @brief
 * The gaussian typing keyboard.
 */
class GaussianKeyboardError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mKeyboard = noiser.mGK;
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
      dstring rToken = cSent.tokens[rW].dup;

      Array!string errors = this.mKeyboard.generate_typos(to!string(rToken));

      if (errors.length > 1) {
        ulong rT = NoiserUtility.getRandomPosition(0, errors.length - 1, this.mRnd);

        dstring tToken = to!dstring(errors[rT]);
        if (tToken.length > 0) {
          if (tToken != rToken) {
            if (NoiserUtility.inLangDict(tToken, this.mpLanguage.getKeyNeighbourhood())) {
              if (NoiserUtility.isWrongPronoun(this.mpLanguage, rToken, tToken)) {
                cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
              }
              else {
                cSent.errors[rW] = ErrorTypes.REAL_WORD;
              }
            } else {
              cSent.errors[rW] = ErrorTypes.NON_WORD;
            }
            cSent.setTokenMark(rW, MarkTypes.SINGLE);
            cSent.tokens[rW] = tToken;
          }
        }
        if (cSent.tokens[rW] is cSent.initials[rW]) {
          cSent.errors[rW] = ErrorTypes.NONE;
        }
      }
    }

    return cSent;
  }

  /** The Gaussian keyboard for the current language-layout **/
  GaussianKeyboard mKeyboard;
  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}
