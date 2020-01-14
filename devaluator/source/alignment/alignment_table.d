// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.alignment_table;

import devaluator.utils.types;
import devaluator.utils.helper: PredictionRepr, PredictionSentence, PredictionToken, SourceSentence, SourceToken;

import std.stdio;
import std.algorithm;
import std.algorithm.comparison: levenshteinDistance;
import std.string;
import std.conv;


/**
 * @class
 * AlignmentToken
 *
 * @brief
 * This is a single token from the alignment table. Such a tokens knows
 * its own groundtruth id as well as all ids from the source and prediction
 * it belongs to. Further it has knowledge about the current and the correct
 * token as well as the error type and whether it was already checked in the
 * evaluation phase.
 */
class AlignmentToken {
  /**
   * @brief
   * Default constructor.
   */
  this() {
    this.error_type = ErrorTypes.NONE;
    this.checked = false;
  }

  /**
   * @brief
   * Constructor.
   *
   * @param [in]id
   * The id of the groundtruth information.
   * @param [in]source_id
   * Array containing all source ids that are associatd with this token.
   * @param [in]token
   * The current token.
   * @param [in]correct
   * The correct token.
   * @param [in]error_type
   * The error type of this token.
   * @param [in]checked
   * Determines whether the element was already checked.
   */
  this(ulong id, ulong[] source_id, dstring token, dstring correct, ErrorTypes error_type, bool checked) {
    this.id = id;
    this.source_id = source_id;
    this.token = token;
    this.correct = correct;
    this.error_type = error_type;
    this.adequately_corrected = false;
    this.checked = checked;
  }

  /**
   * @brief
   * Responsible for making the entries of the prediction unique. Typically
   * we've added during the building of the alignment added the same entries
   * multiple times. Through this step we are removing all of these duplicate
   * entries.
   */
  void makeUnique() {
    this.prediction_id.length -= this.prediction_id.sort().uniq().copy(this.prediction_id).length;
  }

  void toString(scope void delegate(const(char)[]) sink) const {
    sink(format("[%d|%s]\n", this.id, this.token));
    sink("\tsids: "); sink(to!string(this.source_id)); sink("\n");
    sink("\tpids: "); sink(to!string(this.prediction_id)); sink("\n");
  }

  /**
   * the ID of the groundtruth.
   */
  ulong id;
  /**
   * The IDs of the source.
   */
  ulong[] source_id;
  /**
   * The IDs of the prediction.
   */
  ulong[] prediction_id;
  /**
   * The source token.
   */
  dstring token;
  /**
   * The correct token.
   */
  dstring correct;
  /**
   * The error type of this token.
   */
  ErrorTypes error_type;

  /**
   * Determines whether the token was adequately corrected (true if yes, false otherwise).
   */
  bool adequately_corrected;
  /**
   * Determines whether this token was already checked.
   */
  bool checked;
}

/**
 * @class
 * AlignmentTable
 *
 * @brief
 * The AlignmentTable holds the information for one specific sentence of a given
 * article.
 */
class AlignmentTable {
  /**
   * @brief
   * default constructor.
   */
  this() {

  }

  /**
   * @brief
   * Indexing operator.
   *
   * @param [in]tidx
   * The ID of the AlignmentToken to return.
   *
   * @return
   * Reference to the AlignmentToken at position tidx.
   */
  ref AlignmentToken opIndex(ulong tidx) {
    return this.tokens[tidx];
  }


  /**
   * @brief
   * Preallocated enough space for the @p numTokens.
   *
   * @param [in]numTokens
   * The number of tokens for this sentence.
   */
  void preallocate(ulong numTokens) {
    for (int i = 0; i < numTokens; i++) {
      this.tokens[i] = new AlignmentToken();
    }
  }

  /**
   * @brief
   * Adds an additional token to the list of tokens.
   *
   * @param [in]token
   * The token that should be added.
   */
  void addToken(AlignmentToken token) {
    this.tokens[this.tokens.length] = token;
  }

  /**
   * @brief
   * Returns a reference to the token at position @p tidx.
   *
   * @param [in]tidx
   * The ID of the AlignmentToken to return.
   *
   * @return
   * Reference to the AlignmentToken at position tidx.
   */
  ref AlignmentToken getToken(ulong tidx) {
    assert (0 <= tidx && tidx < this.tokens.length, "Exceed length of tokens");
    return this.tokens[tidx];
  }


  bool appendToPredictionWithSrc(ulong source_id, ulong prediction_id) {
    bool newlyAdded = false;
    for(ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].source_id.canFind(source_id)) {
        if (!this.tokens[tidx].prediction_id.canFind(prediction_id)) {
          newlyAdded = true;
        }
        this.tokens[tidx].prediction_id ~= prediction_id;
      }
    }
    return newlyAdded;
  }

  void appendToPredictionWithSrc(long source_id, long[] prediction_id) {
    for(ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].source_id.canFind(source_id)) {
        this.tokens[tidx].prediction_id ~= prediction_id;
      }
    }
  }



  void toString(scope void delegate(const(char)[]) sink) const {
    sink("AlignmentTable [\n");
    for (int t = 0; t < this.tokens.length; t++) {
      sink("\tid: "); sink(to!string(this.tokens[t].id)); sink(" ");
      sink("\tsource_id: "); sink(to!string(this.tokens[t].source_id)); sink(" ");
      sink("\tprediction_id: "); sink(to!string(this.tokens[t].prediction_id)); sink(" ");
      sink("\ttoken: "); sink(to!string(this.tokens[t].token)); sink(" ");
      sink("\tcorrect: "); sink(to!string(this.tokens[t].correct)); sink(" ");
      sink("\tchecked: "); sink(to!string(this.tokens[t].checked)); sink("\n");
    }
    sink("]\n");
  }

  /**
   * @brief
   * Responsible for making all ID entries within all tokens unique.
   */
  void makeUnique() {
    foreach (t; this.tokens) {
      t.makeUnique();
    }
  }

  bool isPredictionIdInOthersExcept(ulong pidx, ulong otidx) {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (otidx != tidx) {
        if ((this.tokens[tidx].prediction_id.length == 1) && this.tokens[tidx].prediction_id.canFind(pidx)) {
          return true;
        }
      }
    }
    return false;
  }

  void resolveMultiplePredictions() {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].prediction_id.length > 1) {
        ulong pidx = 0;
        while (pidx < this.tokens[tidx].prediction_id.length) {
          ulong p_elem = this.tokens[tidx].prediction_id[pidx];

          // Is there already a unique connection?
          if (this.isPredictionIdInOthersExcept(p_elem, tidx)) {
            this.tokens[tidx].prediction_id = remove(this.tokens[tidx].prediction_id, pidx);
          } else {
            pidx++;
          }
        }
      }
    }
  }

  // id: 20 	source_id: [20] 	prediction_id: [20] 	token: the 	correct: the 	checked: true
  // id: 21 	source_id: [21] 	prediction_id: [21, 22] 	token: Mau 	correct: Mau 	checked: false
  // id: 22 	source_id: [22] 	prediction_id: [21, 22] 	token: Mau 	correct: Mau 	checked: false
  // id: 23 	source_id: [23] 	prediction_id: [23] 	token: uprising 	correct: uprising 	checked: true
  void findAndResolveSimilarPatches() {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].prediction_id.length > 1) {
        if (this.findPredictionIdGroupInOthers(this.tokens[tidx].prediction_id) == this.tokens[tidx].prediction_id.length) {
          ulong[] entries = this.getOccurencesOfPredictionIdGroup(this.tokens[tidx].prediction_id);
          ulong[] spreadings = this.tokens[tidx].prediction_id;

          for (ulong eidx = 0; eidx < entries.length; eidx++) {
            this.tokens[entries[eidx]].prediction_id = [spreadings[eidx]];
          }
        }
      }
    }
  }

  ulong findPredictionIdGroupInOthers(ulong[] group) {
    ulong result = 0;
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].prediction_id == group) {
        result++;
      }
    }
    return result;
  }

  ulong[] getOccurencesOfPredictionIdGroup(ulong[] group) {
    ulong[] result;
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].prediction_id == group) {
        result ~= tidx;
      }
    }
    return result;
  }

  long[] getGrouthtruthIDsOfTokenWithPredictionID(long nID) {
    long[] result;
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].prediction_id.canFind(nID)) {
        result ~= tidx;
      }
    }
    return result;
  }

  long[] getGrouthtruthIDsOfTokenWithSourceID(long nID) {
    long[] result;
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].source_id.canFind(nID)) {
        result ~= tidx;
      }
    }
    return result;
  }

  void relocateWronglyPlacedPredictionIds(ref SourceSentence source, ref PredictionSentence prediction) {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      ulong tidx_len = this.tokens[tidx].prediction_id.length;

      if (tidx_len > 1) {
        // Search neighbourhood
        ulong[] p_ids = this.tokens[tidx].prediction_id;

        bool foundPlacement = false;

        // Search prev
        if (tidx >= 1) {
          if (this.tokens[tidx-1].source_id.length == 2) {
            if ((source[this.tokens[tidx-1].source_id[1]].token == prediction[p_ids[p_ids.length-2]].token) ||
                (levenshteinDistance(source[this.tokens[tidx-1].source_id[1]].token, prediction[p_ids[p_ids.length-2]].token) <= 2)) {
              this.tokens[tidx-1].prediction_id ~= p_ids[p_ids.length-2];
              this.tokens[tidx].prediction_id = remove(this.tokens[tidx].prediction_id, p_ids.length-2);
              foundPlacement = true;
            }
          }
        }



        // Search next (foundPlacement is false) &&
        if (tidx < (this.tokens.length - 1)) {
          if (this.tokens[tidx+1].source_id.length == 2) {
            if ((source[this.tokens[tidx+1].source_id[1]].token == prediction[p_ids[1]].token) ||
                (levenshteinDistance(source[this.tokens[tidx+1].source_id[1]].token, prediction[p_ids[1]].token) <= 2)) {
              this.tokens[tidx+1].prediction_id ~= p_ids[1];
              this.tokens[tidx].prediction_id = remove(this.tokens[tidx].prediction_id, 1);
              foundPlacement = true;
            }
          }
        }
      }
    }
  }

  void checkForDifferentMatches(ref SourceSentence source, ref PredictionSentence prediction) {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      ulong p_len = this.tokens[tidx].prediction_id.length;

      if (p_len > 2) {
        ulong[] p_ids = this.tokens[tidx].prediction_id;


      }
    }
  }

  void removeFromOthersExcept(ulong removeThis, ulong exceptThis) {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (tidx != exceptThis) {
        if ((this.tokens[tidx].prediction_id.length > 1) && (this.tokens[tidx].prediction_id.canFind(removeThis))) {
          this.tokens[tidx].prediction_id = remove(
            this.tokens[tidx].prediction_id,
            countUntil(this.tokens[tidx].prediction_id, removeThis)
          );
        }
      }
    }
  }

  void removeFromOthersExcept(ulong[] removeThis, ulong exceptThis) {
    for (ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (tidx != exceptThis) {
        for (ulong pidx = 0; pidx < removeThis.length; pidx++) {
          auto pElem = removeThis[pidx];
          if ((this.tokens[tidx].prediction_id.length > 1) && (this.tokens[tidx].prediction_id.canFind(pElem))) {
            this.tokens[tidx].prediction_id = remove(
              this.tokens[tidx].prediction_id,
              countUntil(this.tokens[tidx].prediction_id, pElem)
            );
          }
        }
      }
    }
  }

  bool isErrorFree() {
    for(ulong tidx = 0; tidx < this.tokens.length; tidx++) {
      if (this.tokens[tidx].error_type != ErrorTypes.NONE) {
        return false;
      }
    }

    return true;
  }

  /**
   * @brief
   * Returns the number of tokens for the current AlignmentTable.
   *
   * @return
   * Number of tokens.
   */
  ulong numTokens() {
    return this.tokens.length;
  }

  /**
   * @brief
   * Determines and return if there are multiple ID elements in either source_id
   * or prediction_id for token @p tidx.
   *
   * @param [in]tidx
   * The token to investigate.
   *
   * @return
   * True if there are multiple ID entry for one of source_id or prediction_id.
   */
  bool isUnambiguous(ulong tidx) {
    return ((this.tokens[tidx].source_id.length > 1) || (this.tokens[tidx].prediction_id.length > 1));
  }

  /**
   * @brief
   * This method returns the amount of tokens which have an error type != NONE.
   *
   * @return
   * Exact amount of errors within the currently investigated sentence.
   */
  ulong numErroneousTokens() {
    ulong result = 0;

    foreach (t; this.tokens) {
      if (t.error_type != ErrorTypes.NONE) {
        result += 1;
      }
    }

    return result;
  }

  bool equalTo(ulong aidx, ulong sidx, ref PredictionRepr prediction) {
    if (this.numTokens() == prediction.getNumTokens(aidx, sidx)) {
      for (ulong tidx = 0; tidx < this.numTokens(); tidx++) {
        if (this[tidx].correct != prediction[aidx][sidx][tidx].token) {
          return false;
        }
      }
      return true;
    }
    return false;
  }


  /**
   * List of all tokens, thereby these are the tokens for a single
   * sentence. For an overview of all sentences take a look into the
   * corresponding CrossLinkage implementation.
   */
  AlignmentToken[ulong] tokens;
}

class AlignmentArticle {

  this() {

  }

  ref AlignmentTable opIndex(ulong nIdx) {
    return this.sentences[nIdx];
  }

  AlignmentTable[ulong] sentences;
}