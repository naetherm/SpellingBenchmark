// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.nop;

import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.helper;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * NopError
 *
 * @brief
 * this specific implementation does nothing to the incoming sentence.
 * the sentence will be returned as it is.
 */
class NopError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {

  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    return cSent;
  }
}
