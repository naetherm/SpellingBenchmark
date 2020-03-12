// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.concatenate;

import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * WordConcatenationError
 *
 * @brief
 * Concatenates two words, the current one and the next one, if the next word
 * is of type "word" and not a punctuation symbol.
 */
class WordConcatenationError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // Only if the length is logn enough
    if (cSent.getNumCurrentTokens() > 2) {
      // Get random position
      ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 2, this.mRnd);

      // Always concatenate with the next element, but only if both elements are no punctuation
      if ((cSent.errors[rW] == ErrorTypes.NONE) &&
          (cSent.errors[rW+1] == ErrorTypes.NONE) &&
          NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
          NoiserUtility.IsEditable(cSent.errors[rW+1], bFurtherDestruction) &&
          !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
          !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW+1])) {
        dstring sToken = cSent.tokens[rW].dup;

        // Add the same word at the next position
        cSent.spaces[rW] = false; // The previous element will now have a space
        cSent.errors[rW] = ErrorTypes.CONCATENATION; // Correct the error type
        cSent.setTokenMark(rW, MarkTypes.START);
        cSent.errors[rW+1] = ErrorTypes.CONCATENATION; // Correct the error type
        cSent.setTokenMark(rW+1, MarkTypes.END);
        cSent.setTokenMarkPosition(rW, MarkPosition.GROUNDTRUTH);
        cSent.setTokenMarkPosition(rW+1, MarkPosition.GROUNDTRUTH);
      }
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
}
