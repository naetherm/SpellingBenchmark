// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.results;

import devaluator.utils.helper: Table;
import devaluator.utils.language: Language;
import std.container;
import std.string;
import std.math;

/**
 * @class
 * Category
 *
 * @brief
 * Brief information about a specific error category. This implementation
 * contains just the information.
 */
class Category {
  /**
   * @brief
   * Constructor.
   */
  this(string name) {
    this.name = name;
  }

  string name;
  int total;
  int found;
  float detection_tp;
  float detection_fp;
  float detection_tn;
  float detection_fn;
  float correction_tp;
  float correction_fp;
  float correction_tn;
  float correction_fn;
}

/**
 * @class
 * EvaluationCategory
 *
 * @brief
 * This is the specific implementation which also contains methods for
 * handling all the data.
 */
class EvaluationCategory : Category {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]name
   * The name of the category.
   * @param [in]beta
   * Beta used for the f-score calculation.
   */
  this(string name, float beta=1.0) {
    super(name);
    this.beta = beta;
  }

  void update() {
    //
    // Detection
    //
    if ((this.detection_tp + this.detection_fp) == 0.0) {
      this.detection_p = 0.0;
    } else {
      this.detection_p = float(this.detection_tp) / (this.detection_tp + this.detection_fp);
    }
    if ((this.detection_tp + this.detection_fn) == 0.0) {
      this.detection_r = 0.0;
    } else {
      this.detection_r = float(this.detection_tp) / (this.detection_tp + this.detection_fn);
    }

    // Here we calculate the harmonic F1-Score, we could also calc the F0.5-Score
    if (((1.0 + pow(this.beta, 2))*this.detection_tp + pow(this.beta, 2)*this.detection_fn + this.detection_fp) == 0.0) {
      this.detection_f = 0.0;
    } else {
      this.detection_f = ((1.0 + pow(this.beta, 2))*this.detection_tp) / ((1.0 + pow(this.beta, 2))*this.detection_tp + pow(this.beta, 2)*this.detection_fn + this.detection_fp);
    }


    //
    // Correction
    //
    if ((this.correction_tp + this.correction_fp) == 0.0) {
      this.correction_p = 0.0;
    } else {
      this.correction_p = float(this.correction_tp) / (this.correction_tp + this.correction_fp);
    }
    if ((this.correction_tp + this.correction_fn) == 0.0) {
      this.correction_r = 0.0;
    } else {
      this.correction_r = float(this.correction_tp) / (this.correction_tp + this.correction_fn);
    }

    // Here we calculate the harmonic F1-Score, we could also calc the F0.5-Score
    if (((1.0 + pow(this.beta, 2))*this.correction_tp + pow(this.beta, 2)*this.correction_fn + this.correction_fp) == 0.0) {
      this.correction_f = 0.0;
    } else {
      this.correction_f = float((1.0 + pow(this.beta, 2))*this.correction_tp) / ((1.0 + pow(this.beta, 2))*this.correction_tp + pow(this.beta, 2)*this.correction_fn + this.correction_fp);
    }
  }

  float beta;
  float detection_p;
  float detection_r;
  float detection_f;
  float correction_p;
  float correction_r;
  float correction_f;
}

class ResultEntry {

  this(ref Language langDict) {
    this.langDict = langDict;
  }

  void evaluateWholeSequence() {

  }

  private bool checkForCapitalisation(ref dstring grt, ref dstring prd, ref dstring src) {
    return false;
  }

  private bool checkForHyphenation(ref dstring grt, ref dstring prd, ref dstring src) {
    return false;
  }

  private bool checkForPunctuatoin(ref dstring grt, ref dstring prd, ref dstring src) {
    // Punctuation tokens are always just one symbol long
    if (prd.length == 1) {
      import std.uni;
      return isPunctuation(prd[0]);
    }

    return false;
  }

  private bool checkIfRealWord(ref dstring grt, ref dstring prd, ref dstring src) {
    return false;
  }

  private bool checkIfNonWord(ref dstring grt, ref dstring prd, ref dstring src) {
    return false;
  }

  private Language langDict;
}

/**
 * @class
 * ResultTable
 *
 * @brief
 *
 */
class ResultTable {
  /**
   * @brief
   * Constructor.
   */
  this(string program_name) {

  }


  void addResult(string sentence, ResultEntry entry) {

  }

  void addResults(Array!ResultEntry entries) {

  }

  void finalize() {

  }
}
