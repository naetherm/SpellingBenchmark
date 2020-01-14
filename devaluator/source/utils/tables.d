// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.tables;

import devaluator.utils.types;
import devaluator.utils.helper: PredictionRepr, PredictionSentence, PredictionToken, SourceSentence, SourceToken;

import std.stdio;
import std.algorithm;
import std.algorithm.comparison: levenshteinDistance;
import std.string;
import std.conv;


/**
 * @class
 * GapToken
 *
 * @brief
 * Information about gap tokens.
 */
class GapToken {

  this() {

  }

  bool hasGroundtruth() {
    return !this.groundtruth_ids.empty;
  }

  bool hasSource() {
    return !this.groundtruth_ids.empty;
  }

  bool hasPrediction() {
    return !this.groundtruth_ids.empty;
  }

  GroupAssociation getAssociation() {
    return this.association;
  }

  long[] groundtruth_ids;
  long[] source_ids;
  long[] prediction_ids;

  GroupAssociation association;
  long prevToken;
  long nextToken;
}

/**
 * @class
 * GapTable
 *
 * @brief
 */
class GapTable {
  /**
   * @brief
   * Constructor.
   */
  this() {

  }

  /**
   * @brief
   * Indexing operator.
   *
   * @param [in]tidx
   * The index position of the token to return.
   *
   * @return
   * Reference to the token at index position @p tidx.
   */
  ref GapToken opIndex(ulong tidx) {
    return this.gaps[tidx];
  }

  ulong numTokens() {
    return this.gaps.length;
  }

  /**
   * @brief
   * Allocates space for a new GapToken.
   */
  void addToken() {
    this.gaps[this.gaps.length] = new GapToken();
  }

  /**
   * @brief
   * Returns a reference to the last gap token of the current gap table.
   *
   * @return
   * Reference to the last token of the table.
   */
  ref GapToken last() {
    return this.gaps[this.gaps.length-1];
  }

  /**
   * @brief
   *
   * @param [in]predictionIDs
   * The list of prediction ids to check for.
   *
   * @return
   * True if the list of prediction ids is already present, false otherwise.
   */
  bool isPredictionAlreadyPresent(long[] predictionIDs) {
    foreach(t; this.gaps) {
      if (t.prediction_ids == predictionIDs) {
        return true;
      }
    }

    return false;
  }

  void addSourceAssociatedWithPrediction(long[] predictionIDs, long[] sourceIDs) {
    foreach(ref t; this.gaps) {
      if (t.prediction_ids == predictionIDs) {
        t.source_ids ~= sourceIDs;
      }
    }
  }


  void toString(scope void delegate(const(char)[]) sink) const {
    sink("GapTable [\n");
    for (int t = 0; t < this.gaps.length; t++) {
      sink("\tgroundtruth_ids: "); sink(to!string(this.gaps[t].groundtruth_ids)); sink(" ");
      sink("\tsource_ids: "); sink(to!string(this.gaps[t].source_ids)); sink(" ");
      sink("\tprediction_ids: "); sink(to!string(this.gaps[t].prediction_ids)); sink(" ");
      sink("\tassociation: "); sink(to!string(this.gaps[t].association)); sink(" ");
      sink("\tprev: "); sink(to!string(this.gaps[t].prevToken)); sink(" ");
      sink("\tnext: "); sink(to!string(this.gaps[t].nextToken)); sink("\n");
    }
    sink("]\n");
  }

  /**
   * List of all associated gaps.
   */
  GapToken[ulong] gaps;
}
