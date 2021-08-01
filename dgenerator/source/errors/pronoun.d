// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.pronoun;

import std.conv;
import std.random: Random;
import std.uni;
import std.stdio;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * PronounError
 *
 * @brief
 * ???
 */
class PronounError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {

    // Check if we can find a indirect mentioning within the given sentence

    ulong[] lstTokens;

    for (ulong i = 0; i < cSent.getNumCurrentTokens(); ++i) {
      if ((toLower(cSent.tokens[i]) in this.mpLanguage.getPronounsTable()) && (cSent.errors[i] == ErrorTypes.NONE)) {
        // Append the id to lstTokens
        lstTokens ~= i;
      }
    }

    // We will now fetch one id out of lstTokens, if there is any id at all
    if (lstTokens.length >= 1) {
      ulong rndPronounPos = NoiserUtility.getRandomPosition(0, lstTokens.length - 1, this.mRnd);

      // Fetch list of wrong pronouns
      auto pPronounTable = this.mpLanguage.getPronounTableByKey(toLower(cSent.tokens[lstTokens[rndPronounPos]]));

      auto rndWrongPronoun = NoiserUtility.getRandomPosition(0, pPronounTable.getNumWrongPronouns() - 1, this.mRnd);

      if (NoiserUtility.isCapitalized(cSent.tokens[lstTokens[rndPronounPos]])) {
        cSent.tokens[lstTokens[rndPronounPos]] = to!dstring(asCapitalized(pPronounTable.getWrongPronoun(rndWrongPronoun)));
      } else {
        cSent.tokens[lstTokens[rndPronounPos]] = pPronounTable.getWrongPronoun(rndWrongPronoun);
      }
      cSent.errors[lstTokens[rndPronounPos]] = ErrorTypes.MENTION_MISMATCH;

    } // Nothing to do right now

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;

}
