// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.evaluation;

import devaluator.utils.types;
import std.algorithm.setops;
import std.string;
import std.traits;
import std.math;
import std.conv;

/**
 * @class
 * ErrorCategory
 *
 * @brief
 */
class ErrorCategory {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]name
   * The name of the category.
   */
  this(string name) {
    this.name = name;
  }

  void finalize() {
    // Precision
    if ((this.detection_tp + this.detection_fp) == 0) {
      this.detection_precision = 0.0;
    } else {
      this.detection_precision = this.detection_tp / (this.detection_tp + this.detection_fp);
    }
    if ((this.correction_tp + this.correction_fp) == 0) {
      this.correction_precision = 0.0;
    } else {
      this.correction_precision = this.correction_tp / (this.correction_tp + this.correction_fp);
    }
    // Recall
    if ((this.detection_tp + this.detection_fn) == 0) {
      this.detection_recall = 0.0;
    } else {
      this.detection_recall = this.detection_tp / (this.detection_tp + this.detection_fn);
    }
    if ((this.correction_tp + this.correction_fn) == 0) {
      this.correction_recall = 0.0;
    } else {
      this.correction_recall = this.correction_tp / (this.correction_tp + this.correction_fn);
    }

    // F-Score
    if (((pow(this.beta, 2))*this.detection_precision + this.detection_recall) == 0.0) {
      this.detection_fscore = 0.0;
    } else {
      this.detection_fscore = ((1.0 + pow(this.beta, 2))*this.detection_precision*this.detection_recall) / (pow(this.beta, 2)*this.detection_precision + this.detection_recall);
    }
    if (((pow(this.beta, 2))*this.correction_precision + this.correction_recall) == 0.0) {
      this.correction_fscore = 0.0;
    } else {
      this.correction_fscore = ((1.0 + pow(this.beta, 2))*this.correction_precision*this.correction_recall) / (pow(this.beta, 2)*this.correction_precision + this.correction_recall);
    }

    if (isNaN(this.detection_fscore)) {
      this.detection_fscore = 0.0;
    }
    if (isNaN(this.correction_fscore)) {
      this.correction_fscore = 0.0;
    }
  }

  string name;

  ulong total = 0;
  ulong found = 0;
  ulong corrected = 0;

  float beta = 1.0;

  float detection_fp = 0.0;
  float detection_fn = 0.0;
  float detection_tp = 0.0;
  float detection_tn = 0.0;
  float correction_fp = 0.0;
  float correction_fn = 0.0;
  float correction_tp = 0.0;
  float correction_tn = 0.0;

  float detection_precision = 0.0;
  float detection_recall = 0.0;
  float detection_fscore = 0.0;
  float correction_precision = 0.0;
  float correction_recall = 0.0;
  float correction_fscore = 0.0;
}

/**
 * @class
 * EvaluationTable
 *
 * @brief
 *
 */
class EvaluationTable {
  /**
   * @brief
   * Default constructor.
   */
  this() {
    // Initialize all tables
    this.initialize();
    // Initialize the confusion matrix
    //this.confusionMatrix = new long[][](10, 10);

    this.equalInfluenceScore = 0;
    this.penalizedScore = 0;

    this.numErrors = 0;
    this.numCorrectWords = 0;
    this.numTotalWords = 0;
    this.numSequence = 0;
    this.numErrorFreeSentences = 0;
    this.numCorrectSequence = 0;
    this.suggestionAdequacy = 0.0;
    this.numSuggestions = 0;

    this.detectedErrors = 0.0;
    this.correctedErrors = 0.0;

    this.detectionAverageAccuracy = 0.0;
    this.detectionErrorRate = 0.0;
    this.correctionAverageAccuracy = 0.0;
    this.correctionErrorRate = 0.0;
    this.detectionPrecision = 0.0;
    this.detectionRecall = 0.0;
    this.detectionFScore = 0.0;
    this.correctionPrecision = 0.0;
    this.correctionRecall = 0.0;
    this.correctionFScore = 0.0;
  }

  /**
   * @brief
   * Returns the whole evaluation table as json.
   */
  dstring asJson() {
    dstring result;

    result ~= "{ \"evaluation\": {";
    result ~= "\"equalScore\": " ~ to!dstring(this.equalInfluenceScore);
    result ~= ", \"penalizedScore\": " ~ to!dstring(this.penalizedScore);
    result ~= ", \"wordAccuracy\": " ~ to!dstring(this.wordAccuracy);
    result ~= ", \"sequenceAccuracy\": " ~ to!dstring(this.sequenceAccuracy);
    result ~= ", \"numSentences\": " ~ to!dstring(this.numSequence);
    result ~= ", \"numErrorFreeSentences\": " ~ to!dstring(this.numErrorFreeSentences);
    result ~= ", \"numCorrectedSentences\": " ~ to!dstring(this.numCorrectSequence);
    result ~= ", \"detectionPrecision\": " ~ to!dstring(this.detectionPrecision);
    result ~= ", \"detectionRecall\": " ~ to!dstring(this.detectionRecall);
    result ~= ", \"detectionFScore\": " ~ to!dstring(this.detectionFScore);
    result ~= ", \"correctionPrecision\": " ~ to!dstring(this.correctionPrecision);
    result ~= ", \"correctionRecall\": " ~ to!dstring(this.correctionRecall);
    result ~= ", \"correctionFScore\": " ~ to!dstring(this.correctionFScore);
    result ~= ", \"detectionAccuracy\": " ~ to!dstring(this.detectionAverageAccuracy);
    result ~= ", \"detectionErrorRate\": " ~ to!dstring(this.detectionErrorRate);
    result ~= ", \"correctionAccuracy\": " ~ to!dstring(this.correctionAverageAccuracy);
    result ~= ", \"correctionErrorRate\": " ~ to!dstring(this.correctionErrorRate);
    result ~= ", \"numWords\": " ~ to!dstring(this.numTotalWords);
    result ~= ", \"numErrors\": " ~ to!dstring(this.numErrors);
    result ~= ", \"detectedErrors\": " ~ to!dstring(this.detectedErrors);
    result ~= ", \"correctedErrors\": " ~ to!dstring(this.correctedErrors);
    result ~= ", \"suggestionAdequacy\": " ~ to!dstring(this.suggestionAdequacy);

    foreach(c; this.categories) {
      result ~= ", ";
      result ~= "\"" ~ to!dstring(c.name) ~ "\": {";
      result ~= "\"detectionPrecision\": " ~ to!dstring(c.detection_precision);
      result ~= ", \"detectionRecall\": " ~ to!dstring(c.detection_recall);
      result ~= ", \"detectionFScore\": " ~ to!dstring(c.detection_fscore);
      result ~= ", \"correctionPrecision\": " ~ to!dstring(c.correction_precision);
      result ~= ", \"correctionRecall\": " ~ to!dstring(c.correction_recall);
      result ~= ", \"correctionFScore\": " ~ to!dstring(c.correction_fscore);
      result ~= ", \"total\": " ~ to!dstring(c.total);
      result ~= ", \"found\": " ~ to!dstring(c.found);
      result ~= ", \"corrected\": " ~ to!dstring(c.corrected);
      // detection
      result ~= ", \"detection\": {";
      result ~= "\"fp\": " ~ to!dstring(c.detection_fp);
      result ~= ", \"fn\": " ~ to!dstring(c.detection_fn);
      result ~= ", \"tp\": " ~ to!dstring(c.detection_tp);
      result ~= ", \"tn\": " ~ to!dstring(c.detection_tn);

      // correction
      result ~= "}, \"correction\": {";
      result ~= "\"fp\": " ~ to!dstring(c.correction_fp);
      result ~= ", \"fn\": " ~ to!dstring(c.correction_fn);
      result ~= ", \"tp\": " ~ to!dstring(c.correction_tp);
      result ~= ", \"tn\": " ~ to!dstring(c.correction_tn);

      result ~= "} }";
    }

    result ~= "} }";

    return result;
  }


  /**
   * @brief
   * Indexing operator.
   *
   * @param [in]type
   * The type for which a reference to the evaluation should be returned.
   *
   * @return
   * Reference to the category defined by @p type.
   */
  ref ErrorCategory opIndex(ErrorTypes type) {
    return this.categories[type];
  }


  /**
   * @brief
   * Initialize the internally used array for all error categories.
   */
  private void initialize() {
    foreach (i, error_type; EnumMembers!ErrorTypes) {
      this.categories[error_type] = new ErrorCategory(to!string(error_type));
    }
  }

  void increaseTNCountsExcept(ErrorTypes[] correctlyPredicted) {
    foreach(e; setDifference([EnumMembers!ErrorTypes], correctlyPredicted)) {
      this.categories[e].detection_tn += 1;
      this.categories[e].correction_tn += 1;
    }
  }

  void incrementFoundExcept(ErrorTypes[] errorTypes) {
    foreach(e; errorTypes) {
      this.categories[e].found += 1;
    }
  }

  void incrementCorrected(ErrorTypes errorType) {
    this.categories[errorType].corrected += 1;
  }

  void finalize() {
    //this.numErrors = 0;
    ulong scoreDivider = 0;
    foreach(i, error_type; EnumMembers!ErrorTypes) {
      this.categories[error_type].finalize();
      ulong total_ = 0;
      if (this.categories[error_type].total != 0) {
        scoreDivider += 1;
        this.equalInfluenceScore += float(this.categories[error_type].corrected)/float(this.categories[error_type].total);
        if (error_type != ErrorTypes.NONE) {
          this.penalizedScore += float(this.categories[error_type].corrected)/float(this.categories[error_type].total);
        }
      }

      //this.numErrors += this.categories[error_type].total;
    }

    if (scoreDivider!=1) {
      this.penalizedScore /= float(scoreDivider-1);
      this.penalizedScore *= (float(this.categories[ErrorTypes.NONE].corrected)/float(this.categories[ErrorTypes.NONE].total));
    }
    this.equalInfluenceScore /= float(scoreDivider);

    if (this.numTotalWords > 0) {
      this.wordAccuracy = this.numCorrectWords / this.numTotalWords;
    } else {
      this.wordAccuracy = 0.0;
    }
    if (this.numSequence > 0) {
      this.sequenceAccuracy = this.numCorrectSequence / this.numSequence;
    } else {
      this.sequenceAccuracy = 0.0;
    }

    float detNum = 0.0;
    float detDenomP = 0.0;
    float detDenomR = 0.0;
    float corrNum = 0.0;
    float corrDenomP = 0.0;
    float corrDenomR = 0.0;

    // Calculate Average Accuracy
    foreach(i, error_type; EnumMembers!ErrorTypes) {
      if (error_type != ErrorTypes.NONE) {
        if ((this.categories[error_type].detection_tp == 0) &&
            (this.categories[error_type].detection_fp == 0) &&
            (this.categories[error_type].detection_fn == 0)) {
          // Rare but special case: TP, FP, and FN are all 0 -> The F1-Score should be 1 in this case
        } else {
          this.detectionAverageAccuracy += (this.categories[error_type].detection_tp + this.categories[error_type].detection_tn) / (this.categories[error_type].detection_tp + this.categories[error_type].detection_tn + this.categories[error_type].detection_fp + this.categories[error_type].detection_tn);
          this.correctionAverageAccuracy += (this.categories[error_type].correction_tp + this.categories[error_type].correction_tn) / (this.categories[error_type].correction_tp + this.categories[error_type].correction_tn + this.categories[error_type].correction_fp + this.categories[error_type].correction_tn);

          this.detectionErrorRate += (this.categories[error_type].detection_fp + this.categories[error_type].detection_fn) / (this.categories[error_type].detection_tp + this.categories[error_type].detection_tn + this.categories[error_type].detection_fp + this.categories[error_type].detection_tn);
          this.correctionErrorRate += (this.categories[error_type].correction_fp + this.categories[error_type].correction_fn) / (this.categories[error_type].correction_tp + this.categories[error_type].correction_tn + this.categories[error_type].correction_fp + this.categories[error_type].correction_tn);

          detNum += this.categories[error_type].detection_tp;
          detDenomP += this.categories[error_type].detection_tp + this.categories[error_type].detection_fp;
          detDenomR += this.categories[error_type].detection_tp + this.categories[error_type].detection_fn;

          corrNum += this.categories[error_type].correction_tp;
          corrDenomP += this.categories[error_type].correction_tp + this.categories[error_type].correction_fp;
          corrDenomR += this.categories[error_type].correction_tp + this.categories[error_type].correction_fn;
        }
      }
    }

    this.detectionAverageAccuracy /= (this.categories.length - 1);
    this.correctionAverageAccuracy /= (this.categories.length - 1);
    this.detectionErrorRate /= (this.categories.length - 1);
    this.correctionErrorRate /= (this.categories.length - 1);

    this.detectionPrecision = detNum / detDenomP;
    this.detectionRecall = detNum / detDenomR;
    this.correctionPrecision = corrNum / detDenomP;
    this.correctionRecall = corrNum / corrDenomR;

    if (isNaN(this.detectionPrecision)) {
      this.detectionPrecision = 0.0;
    }
    if (isNaN(this.correctionPrecision)) {
      this.correctionPrecision = 0.0;
    }
    if (isNaN(this.detectionRecall)) {
      this.detectionRecall = 0.0;
    }
    if (isNaN(this.correctionRecall)) {
      this.correctionRecall = 0.0;
    }

    this.detectionFScore = 2 * (this.detectionPrecision * this.detectionRecall) / (this.detectionPrecision + this.detectionRecall);
    this.correctionFScore = 2 * (this.correctionPrecision * this.correctionRecall) / (this.correctionPrecision + this.correctionRecall);

    if (this.numSuggestions > 0) {
      this.suggestionAdequacy /= this.numSuggestions;
    } else {
      this.suggestionAdequacy = 0;
    }
    if (isNaN(this.detectionFScore)) {
      this.detectionFScore = 0.0;
    }
    if (isNaN(this.correctionFScore)) {
      this.correctionFScore = 0.0;
    }
    if (isNaN(this.equalInfluenceScore)) {
      this.equalInfluenceScore = 0.0;
    }
    if (isNaN(this.penalizedScore)) {
      this.penalizedScore = 0.0;
    }
  }

  /**
   * Associative array of all categories.
   */
  ErrorCategory[ErrorTypes] categories;

  float equalInfluenceScore;
  float penalizedScore;

  /**
   * Total number of errors in all given sentences.
   */
  float numErrors;
  float numCorrectWords;
  float numTotalWords;
  float numSequence;
  float numErrorFreeSentences;
  float numCorrectSequence;

  float detectedErrors;
  float correctedErrors;
  float wordAccuracy;
  float sequenceAccuracy;
  /**
   * For later use: The suggestion adequacy in total.
   */
  float suggestionAdequacy;
  float numSuggestions;

  float detectionAverageAccuracy;
  float detectionErrorRate;
  float correctionAverageAccuracy;
  float correctionErrorRate;
  float detectionPrecision;
  float detectionRecall;
  float detectionFScore;
  float correctionPrecision;
  float correctionRecall;
  float correctionFScore;

  /**
   * Confusion matrix: Really required here?
   */
  //long[][] confusionMatrix;

}
