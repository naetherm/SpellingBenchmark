// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.alignment_linker;

import std.conv;
import std.math;
import std.stdio;
import std.string;
import std.utf;
import std.file;
import std.path;
import std.typecons: Tuple, tuple;
import std.algorithm;
import std.algorithm.iteration;
import std.algorithm.sorting;
import std.algorithm.comparison: levenshteinDistance;

import devaluator.alignment.alignment_table;
import devaluator.alignment.alignment_compiler: AlignmentCompiler;
import devaluator.alignment.correlation_helper: CorrelationHelper;
import devaluator.alignment.gap_table;
import devaluator.utils.eval_helper: EvalHelper;
import devaluator.utils.language: Language;
import devaluator.utils.evaluation;
import devaluator.utils.helper: JoinedGap, Table, RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
import devaluator.utils.nlp;
import devaluator.utils.evaluation;
import devaluator.utils.types;

/**
 * @class
 * AlignmentLinker
 */
class AlignmentLinker {

  /**
   * @brief
   * Constructor.
   *
   * @param [in]cLangDict
   * The language dictionary to use for this linker.
   */
  this(ref Language cLangDict) {
    // Set the currently used language.
    this.mcLangDict = cLangDict;
  }

  /**
   * @brief
   * This method is responsible for initializing the internally used compiler instance which will
   * generate a first basic draft of the underlying alignment and gap tables. After this method is
   * called nothing is calculated. All calculation is done within the build method!
   * After that is done, the build method have to be called, which will fill all remaining gaps
   * with information as good as possible.
   *
   * @param [in]cRaw
   * The raw representation.
   * @param [in]cSource
   * The source representation.
   * @param [in]cGroundtruth
   * The groundtruth representation.
   * @param [in]cPrediction
   * The prediction representation.
   */
  void initialize(ref SourceRepr cSource, ref GroundtruthRepr cGroundtruth, ref PredictionRepr cPrediction) {
    // Create new instance of the compiler
    this.mcCompiler = new AlignmentCompiler(cGroundtruth, cPrediction, cSource);

    // Initialize a new instance of the evaluation table. The garbage collector will take care about the old instance :)
    this.mcETable = new EvaluationTable();
  }

  /**
   * @brief
   * Compile and link the alignment.
   *
   */
  void build() {
    // And build the alignment information
    this.mcCompiler.build();

    foreach (ARTidx; 0..this.mcCompiler.numArticles()) {
      // Now loop through all sentences
      foreach (sidx; 0..this.mcCompiler.numSentences(ARTidx)) {

        GapToken[] unresolvedP2G;
        GapToken[] unresolvedP2S;
        GapToken[] unresolvableP2G;
        GapToken[] unresolvableP2S;
        // Fetch all required data (this is a reference so that wen can change data!)
        auto cAlignments = this.mcCompiler.getAlignment(ARTidx, sidx);
        auto cGaps = this.mcCompiler.getGap(ARTidx, sidx);

        // Loop through all elements of P2G
        foreach(gidx; 0..cGaps.lengthP2G()) {
          auto g = cGaps.p2gAt(gidx);
          if (g.diff() == 0) {
            // Same amount of elements, let's just merge those gaps
            foreach(aidx; 0..g.pred().length()) {
              cAlignments[g.other().left()+aidx].prediction_id ~= g.pred().left()+aidx;
            }
          } else {
            unresolvedP2G ~= g;
          }
        }
        //for (long i = p2g_remove.length-1; i >=0; i++) { cGaps..p2g()}

        // Loop through all elements of P2S
        foreach(gidx; 0..cGaps.lengthP2S()) {
          auto g = cGaps.p2sAt(gidx);
          if (g.diff() == 0) {
            // Same amount of elements, let's just merge those gaps
            foreach(aidx; 0..g.pred().length()) {
              // This case is a bit more complicated because we can only indirectly access the groundtruth-centered
              // alignment information through the source information
              cAlignments.appendToPredictionWithSrc(g.other().left()+aidx, g.pred().left()+aidx);
            }
          } else {
            unresolvedP2S ~= g;
          }
        }

        // We've collected all remaining gaps that cannot be associated through the previous process
        // To handle that probably we should fetch all gap information, create new uncorrelated gap-
        // blocks and repeat the auto stiffing.
        bool bAnyGapInformationChanged = false;

        //writeln("Before GapFitting: AlignmentTable:");
        //writeln(this.mcCompiler.getAlignment(ARTidx, sidx));
        //writeln("Unresolved found gaps:");
        //writeln("P2G=>");
        //foreach(g; unresolvedP2G) {
        //  writeln(g);
        //}
        //writeln("P2S=>");
        //foreach(g; unresolvedP2S) {
        //  writeln(g);
        //}
        writeln("Processing article ", ARTidx, " sentence ", sidx);
        long nTolerance = 1;
        do {
          //writeln("\tWhile resolving");
          writeln("\tP2G=>");
          foreach(g; unresolvedP2G) {
            writeln("\t", g);
          }
          writeln("\tP2S=>");
          foreach(g; unresolvedP2S) {
            writeln("\t", g);
          }
          auto changedP2GGaps = this.postGapFitting(ARTidx, sidx, GroupAssociation.PRD2GRT, cAlignments, unresolvedP2G, nTolerance);
          auto changedP2SGaps = this.postGapFitting(ARTidx, sidx, GroupAssociation.PRD2SRC, cAlignments, unresolvedP2S, nTolerance);

          // TODO(naetherm): Post check:
          //  Loop through all found "gaps" and remove those whose prediction-id is already bound to an element within the alignment table
          unresolvedP2G = [];
          unresolvedP2S = [];
          foreach(g; 0..changedP2GGaps[1].length) {
            bool bAllAssigned = true;

            foreach (pidx; 0..changedP2GGaps[1][g].pred().length()) {
              if (cAlignments.getGrouthtruthIDsOfTokenWithPredictionID(changedP2GGaps[1][g].pred().left()+pidx).empty()) {
                bAllAssigned = false;
                break;
              }
            }
            if (bAllAssigned) {
              // All prediction tokens already aligned, remove that element
            } else {
              // not everything is aligned so far
              unresolvedP2G ~= changedP2GGaps[1][g];
            }
          }
          foreach(g; 0..changedP2SGaps[1].length) {
            bool bAllAssigned = true;

            foreach (pidx; 0..changedP2SGaps[1][g].pred().length()) {
              if (cAlignments.getGrouthtruthIDsOfTokenWithPredictionID(changedP2SGaps[1][g].pred().left()+pidx).empty()) {
                bAllAssigned = false;
                break;
              }
            }
            if (bAllAssigned) {
              // All prediction tokens already aligned, remove that element
            } else {
              // not everything is aligned so far
              unresolvedP2S ~= changedP2SGaps[1][g];
            }
          }

          //unresolvedP2G = changedP2GGaps[1];
          //unresolvedP2S = changedP2SGaps[1];

          bAnyGapInformationChanged = changedP2GGaps[0] || changedP2SGaps[0];
        } while (bAnyGapInformationChanged);

        // Done, the rest is unresolvable
        unresolvableP2G = unresolvedP2G;
        unresolvableP2S = unresolvedP2S;

        cGaps.replaceGapTokens(GroupAssociation.PRD2GRT, unresolvableP2G);
        cGaps.replaceGapTokens(GroupAssociation.PRD2SRC, unresolvableP2S);


        // Latest cleanup
        cAlignments.makeUnique();
        cAlignments.findAndResolveSimilarPatches();

        //writeln("After GapFitting: AlignmentTable:");
        //writeln(this.mcCompiler.getAlignment(ARTidx, sidx));
        //writeln("Unresolvable found gaps:");
        //writeln("P2G=>");
        //foreach(g; unresolvableP2G) {
        //  writeln(g);
        //}
        //writeln("P2S=>");
        //foreach(g; unresolvableP2S) {
        //  writeln(g);
        //}
      }
    }
  }

  void evaluate() {
    // Loop through all sentences
    foreach (ARTidx; 0..this.c().numArticles()) {
      foreach (sidx; 0..this.c().numSentences(ARTidx)) {
        auto cAlignments = this.mcCompiler.getAlignment(ARTidx, sidx);

        // 1) Loop through all entries of the
        this.mcETable.numSequence++;

        if (cAlignments.isErrorFree()) {this.mcETable.numErrorFreeSentences += 1; }
        this.mcETable.numErrors += cAlignments.numErroneousTokens();
        this.mcETable.numTotalWords += this.c().p().getNumTokens(ARTidx, sidx);

        // Collection information about the amount of errors per category
        foreach (tidx; 0..cAlignments.numTokens()) {
          this.mcETable.categories[cAlignments[tidx].error_type].total += 1;
        }

        // Loop through all tokens of the currently observed sentence
        foreach (tidx; 0..cAlignments.numTokens()) {
          bool bEvaluatedErrorType = false;
          // fetch some of the information for less and clearer code
          ulong gid = cAlignments[tidx].id;
          ulong[] sids = cAlignments[tidx].source_id;
          ulong[] pids = cAlignments[tidx].prediction_id;
          ErrorTypes err = cAlignments[tidx].error_type;
          dstring sCorr = cAlignments[tidx].correct;
          dstring sSrc = cAlignments[tidx].token;

          // source and prediction have both length 1 -> direct match
          if ((sids.length == 1) && (pids.length == 1)) {
            auto sid = sids[0];
            auto pid = pids[0];

            // Did the tool tried to predict the error category?
            if (!this.c().p(ARTidx, sidx, pid).type.empty) { // Yes
              if (NameToType(to!string(this.c().p(ARTidx, sidx, pid).type)) == err) {
                // Correct prediction
                this.mcETable[err].detection_tp += 1;
                bEvaluatedErrorType = true;
              } else {
                // Ah sorry, not correction
                this.mcETable[err].detection_fn += 1;
                bEvaluatedErrorType = true;
              }
            }

            // Okay, next: Was the token adequately predicted?
            if (cAlignments[tidx].checked is false) {
              if (this.c().p(ARTidx, sidx, pid).token == sCorr) {
                this.mcETable[err].found += 1;

                if (!bEvaluatedErrorType) {
                  this.mcETable[err].detection_tp += 1;
                  this.mcETable.detectedErrors += 1;
                }
                this.mcETable[err].correction_tp += 1;
                cAlignments[tidx].adequately_corrected = true;

                // Increase true negative counters for all other categories
                this.mcETable.increaseTNCountsExcept([err]);
                this.mcETable.incrementCorrected(err);
                this.mcETable.numCorrectWords += 1;
                if (err != ErrorTypes.NONE) {
                  if (!bEvaluatedErrorType) {
                    this.mcETable.detectedErrors += 1;
                  }
                  this.mcETable.correctedErrors += 1;
                }

                // Mark as checked
                cAlignments[tidx].checked = true;
              }
            }
            // Okay, not corrected. Is it then still the source token?
            if (cAlignments[tidx].checked is false) {
              if (this.c().p(ARTidx, sidx, pid).token == sSrc) {
                this.mcETable[err].detection_fn += 1;
                this.mcETable[err].correction_fn += 1;
                if (err != ErrorTypes.NONE) {
                  this.mcETable[ErrorTypes.NONE].detection_fp += 1;
                  this.mcETable[ErrorTypes.NONE].correction_fp += 1;
                  // Increment the found counter except for NONE
                  this.mcETable.incrementFoundExcept([ErrorTypes.NONE]);
                }
                // Increase the TN counters for all other categories!
                this.mcETable.increaseTNCountsExcept([err, ErrorTypes.NONE]);
                // Mark as checked
                cAlignments[tidx].checked = true;
              }
            }

            // Okay ... neither the source, nor the groundtruth. Let's investigate that further
            if (cAlignments[tidx].checked is false) {
              // First of all: The tool thought of detecting an error
              this.mcETable.detectedErrors += 1;
              this.mcETable[err].detection_fn += 1;
              this.mcETable[err].correction_fn += 1;

              auto sPredicted = this.c().p(ARTidx, sidx, pid).token;

              if (CorrelationHelper.isCapitalisationError(sSrc, sCorr, sPredicted)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.CAPITALISATION].detection_fp += 1;
                  this.mcETable[ErrorTypes.CAPITALISATION].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.CAPITALISATION]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.CAPITALISATION, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isCompoundHyphenError(sSrc, sCorr, sPredicted)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.COMPOUND_HYPHEN].detection_fp += 1;
                  this.mcETable[ErrorTypes.COMPOUND_HYPHEN].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.COMPOUND_HYPHEN]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.COMPOUND_HYPHEN, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isHyphenationError(sSrc, sCorr, sPredicted)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.HYPHENATION].detection_fp += 1;
                  this.mcETable[ErrorTypes.HYPHENATION].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.HYPHENATION]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.HYPHENATION, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isPunctuationError(sSrc, sCorr, sPredicted)) {
                if (cAlignments[tidx].checked is false) {
                  // This case a bit more complex
                  // If the groundtruth is a punctuation char and the category is NONE we through this was a punctuation error
                  if (err == ErrorTypes.NONE) {
                    this.mcETable[ErrorTypes.PUNCTUATION].detection_fp += 1;
                    this.mcETable[ErrorTypes.PUNCTUATION].correction_fp += 1;
                  } else if (err == ErrorTypes.PUNCTUATION) {
                    // If the original error category is a punctuation error we just corrected is false:
                    // So, it was detected that there is something wrong but the correction is false
                    this.mcETable[ErrorTypes.PUNCTUATION].detection_tp += 1;
                    this.mcETable[ErrorTypes.PUNCTUATION].correction_fp += 1;
                  }
                  this.mcETable.incrementFoundExcept([ErrorTypes.PUNCTUATION]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.PUNCTUATION, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isPersonalPronounError(sSrc, sCorr, sPredicted, this.mcLangDict)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.MENTION_MISMATCH].detection_fp += 1;
                  this.mcETable[ErrorTypes.MENTION_MISMATCH].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.MENTION_MISMATCH]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.MENTION_MISMATCH, err]);

                  cAlignments[tidx].checked = true;
                }
              } else if (CorrelationHelper.isTenseError(sSrc, sCorr, sPredicted, this.mcLangDict)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.MENTION_MISMATCH].detection_fp += 1;
                  this.mcETable[ErrorTypes.MENTION_MISMATCH].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.MENTION_MISMATCH]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.MENTION_MISMATCH, err]);

                  cAlignments[tidx].checked = true;
                }
              } else if (CorrelationHelper.isRealWordError(sSrc, sCorr, sPredicted, this.mcLangDict)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.REAL_WORD].detection_fp += 1;
                  this.mcETable[ErrorTypes.REAL_WORD].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.REAL_WORD]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.REAL_WORD, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isNonWordError(sSrc, sCorr, sPredicted, this.mcLangDict)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.NON_WORD].detection_fp += 1;
                  this.mcETable[ErrorTypes.NON_WORD].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.NON_WORD]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.NON_WORD, err]);

                  cAlignments[tidx].checked = true;
                  //continue;
                }
              } else if (CorrelationHelper.isArchaicWordError(sSrc, sCorr, sPredicted, this.mcLangDict)) {
                if (cAlignments[tidx].checked is false) {
                  this.mcETable[ErrorTypes.ARCHAIC].detection_fp += 1;
                  this.mcETable[ErrorTypes.ARCHAIC].correction_fp += 1;
                  this.mcETable.incrementFoundExcept([ErrorTypes.ARCHAIC]);

                  this.mcETable.increaseTNCountsExcept([ErrorTypes.ARCHAIC, err]);

                  cAlignments[tidx].checked = true;
                }
              } else {
                if (cAlignments[tidx].checked is false) {
                  if (err != ErrorTypes.NONE) {
                    this.mcETable[err].detection_tp += 1;
                    this.mcETable[err].correction_fn += 1;
                  } else {
                    this.mcETable[ErrorTypes.NONE].detection_fn += 1;
                    this.mcETable[ErrorTypes.NONE].correction_fn += 1;
                  }
                }
              }

              // Mark as checked
              cAlignments[tidx].checked = true;
            }
          }
          // Now the special cases: The groundtruth is connected to either multiple source or prediction tokens!
          if (sids.length == 1) { // -> Connected to multiple prediction elements
            if (cAlignments[tidx].checked is false) {
              if ((err == ErrorTypes.REPEAT) || (err == ErrorTypes.SPLIT)) { // If this is a split or repeat the number of sids is always 2 ...
                this.mcETable[err].detection_fn += 1;
                this.mcETable[err].correction_fn += 1;
                this.mcETable[ErrorTypes.NONE].detection_fp += 1;
                this.mcETable[ErrorTypes.NONE].correction_fp += 1;
                this.mcETable.incrementFoundExcept([ErrorTypes.NONE]);

                cAlignments[tidx].checked = true;
              } else if ((pids.length == 2) && (err == ErrorTypes.CONCATENATION)) {

              }
            }
          }

          // Special case for |sids| == 2. These errors typically contain only REPEAT and SPLIT
          if (sids.length == 2) {
            if (cAlignments[tidx].checked is false) {
              if ((err == ErrorTypes.REPEAT) || (err == ErrorTypes.SPLIT)) {
                // First: Check if |pids| == 2
                if (pids.length == 2) {
                  // Length is 2, did we change anything?!
                  // Check if sids and pids are still the safe -> we did not change anything and by that don't detect that REPEAT/SPLIT
                  bool bSame = true;
                  foreach (sid; 0..sids.length) {
                    if (this.c().s(ARTidx, sidx, sids[sid]).token != this.c().p(ARTidx, sidx, pids[sid]).token) {
                      bSame = false;
                      break;
                    }
                  }
                  if (bSame) {
                    // Still the same as before, we didn't even try
                    this.mcETable[err].detection_fn += 1;
                    this.mcETable[err].correction_fn += 1;
                    // We thought those are two NONEs
                    this.mcETable[ErrorTypes.NONE].detection_fp += 2;
                    this.mcETable[ErrorTypes.NONE].correction_fp += 2;

                    // Done
                    cAlignments[tidx].checked = true;
                  } else {

                  }
                } else {
                  // Two src-ids but another amount of pids
                  if (pids.length == 1) {
                    // SPLIT or REPEAT: either just made one word out of it

                    if (cAlignments[tidx].correct == this.c().p(ARTidx, sidx, pids[0]).token) {
                      // Corrected it \o/
                      this.mcETable[err].detection_tp += 1;
                      this.mcETable[err].correction_tp += 1;
                      this.mcETable.detectedErrors += 1;

                      cAlignments[tidx].adequately_corrected = true;

                      // Increase true negative counters for all other categories
                      this.mcETable.increaseTNCountsExcept([err]);
                      this.mcETable.incrementCorrected(err);
                      this.mcETable[err].found += 1;

                      cAlignments[tidx].checked = true;
                    } else {
                      if (err == ErrorTypes.SPLIT) {
                        writeln("Ehm ... halp?");
                      } else {
                        // ???
                      }
                    }
                  } else if (pids.length > 2) {
                    // Ehm ... now it is very interesting
                  }
                }
              }
            }
          }

          // Connected to no prediction element, the toold did either erase that element or something other terribly wrong
          if (pids.length == 0) {
            if (cAlignments[tidx].checked is false) {
              this.mcETable[err].detection_fp += 1;
              this.mcETable[err].correction_fp += 1;

              cAlignments[tidx].checked = true;
            }
          }

          if (pids.length == 1) {
            // We know there is only one element in the predictions table
            auto pid = pids[0];

            if (cAlignments[tidx].checked is false)  {
              // TODO(naetherm): What?
              foreach(sid; sids) {

              }

              if (this.c().p(ARTidx, sidx, pid).token == sCorr) {
                this.mcETable[err].detection_tp += 1;
                this.mcETable[err].correction_tp += 1;
                this.mcETable.increaseTNCountsExcept([err]);
                this.mcETable.incrementCorrected(err);
                cAlignments[tidx].adequately_corrected = true;

                this.mcETable.numCorrectWords += 1;
                if (err != ErrorTypes.NONE) {
                  this.mcETable.detectedErrors += 1;
                  this.mcETable.correctedErrors += 1;

                  cAlignments[tidx].checked = true;
                }
              } else {

                if (cAlignments[tidx].checked is false)  {
                  if (this.c().p(ARTidx, sidx, pid).token == sSrc) {
                    this.mcETable[err].detection_fn += 1;
                    this.mcETable[err].correction_fn += 1;

                    if (err != ErrorTypes.NONE) {
                      this.mcETable[ErrorTypes.NONE].detection_fp += 1;
                      this.mcETable[ErrorTypes.NONE].correction_fp += 1;
                      this.mcETable.incrementFoundExcept([ErrorTypes.NONE]);
                    }

                    this.mcETable.increaseTNCountsExcept([ErrorTypes.NONE, err]);
                    cAlignments[tidx].checked = true;
                  }
                }
              }
            }
          }

          // Okay, both, source and prediction tokens are multiple?
          if (cAlignments[tidx].checked is false) {
            // ???
            if ([ErrorTypes.REPEAT, ErrorTypes.SPLIT].canFind(err)) {
              bool bNotCorrected = true;

              if (pids.length == sids.length) {
                foreach (uidx; 0..pids.length) {
                  if (pids[uidx] == sids[uidx]) {
                    bNotCorrected = false;
                  }
                }
              } else {
                bNotCorrected = false;
              }

              if (bNotCorrected) {
                this.mcETable[err].detection_fn += 1;
                this.mcETable[err].correction_fn += 1;
                this.mcETable[ErrorTypes.NONE].detection_fp += 1;
                this.mcETable[ErrorTypes.NONE].correction_fp += 1;
                this.mcETable.incrementFoundExcept([ErrorTypes.NONE]);
              } else {
                this.mcETable.detectedErrors += 1;
                this.mcETable[err].detection_tp += 1;
                this.mcETable[err].correction_fn += 1;
              }

              cAlignments[tidx].checked = true;

            }
          }
        }

        if (cAlignments.equalTo(ARTidx, sidx, this.c().p())) {
          this.mcETable.numCorrectSequence += 1;
        }
      }
    }

    //
    // Investigate the gaps
    //
    // This is a very interesting factor. Did the tool we observed "hallucinate" words into the
    // proposed output? I mean, the only type of gaps we are left with here are NUMTOKENS >= 1 to NONE.
    // The other case would be that there are tokens left wihtin  either the groundtruth or source
    // that are not represented within the prediction -> the tool "forget" those words.
    foreach (ARTidx; 0..this.c().numArticles()) {
      foreach (sidx; 0..this.c().numSentences(ARTidx)) {
        auto cAlignments = this.mcCompiler.getAlignment(ARTidx, sidx);
        auto cGaps = this.mcCompiler.getGap(ARTidx, sidx);

        // First the remaining
        foreach(gidx; 0..cGaps.lengthP2G()) {
          // Get the gap
          auto g = cGaps.p2gAt(gidx);

          if (g.pred().empty()) {
            // No prediction for that token, so we completely forgot that element
            if (!g.other.empty()) {
              foreach(gid; 0..g.other().length()) {
                if (cAlignments[g.other().left()+gid].checked is false) {
                  if (EvalHelper.IsEditablePunctionation(cAlignments[g.other().left()+gid].correct)) {
                    this.mcETable[ErrorTypes.PUNCTUATION].detection_fp += 1;
                    this.mcETable[ErrorTypes.PUNCTUATION].correction_fp += 1;
                  } else {
                    this.mcETable[cAlignments[g.other().left()+gid].error_type].detection_tp += 1;
                    this.mcETable[cAlignments[g.other().left()+gid].error_type].correction_fn += 1;
                  }
                  cAlignments[g.other().left()+gid].checked = true;
                }
              }
            }
          } else if (g.other().empty()) {
            // Prediction element has no groundtruth element -> Gerti reveals she sabotaged it and ...
            if (g.other().left()-1 >= 0) {
              if (endsWith(cAlignments[g.other().left()-1].correct.byDchar, this.c().p(ARTidx, sidx, g.pred().left()).token)) {
                cAlignments[g.other().left()-1].prediction_id ~= g.pred().left();
                if (cAlignments[g.other().left()-1].checked is false) {
                  // TODO: EVAL?
                  cAlignments[g.other().left()-1].checked = true;
                }
              }
            }
            if (g.other.right() < cAlignments.numTokens()) {
              if (endsWith(cAlignments[g.other().right()].correct.byDchar, this.c().p(ARTidx, sidx, g.pred().left()).token)) {
                cAlignments[g.other().right()].prediction_id ~= g.pred().left();
                if (cAlignments[g.other().right()].checked is false) {
                  // TODO: EVAL?
                  cAlignments[g.other().right()].checked = true;
                }
              }
            }
            //  ¯\_(ツ)_/¯
          } else {
            // Both are not empty!
          }
        }

        foreach (gidx; 0..cGaps.lengthP2S()) {
          // Get the gap
          auto g = cGaps.p2sAt(gidx);

          if (g.pred().empty()) {
            // There is at least one element from the source that is connected to no element from the prediction
            // Was the element of the groundtruth already checked
            foreach (gapid; 0..g.other().length()) {
              long[] gids = cAlignments.getGrouthtruthIDsOfTokenWithSourceID(g.other().left()+gapid);

              foreach (gid; 0..gids.length) {
                if (cAlignments[gids[gid]].checked is false) {
                  // Not yet checked. Okay we somehow detected here something but it was not corrected as expected

                  cAlignments[gids[gid]].checked = true;
                }
              }
            }
          }
          if (g.other().empty()) {
            // Prediction element has no source element -> Gerti reveals she sabotaged it and ...
            if (g.other().left()-1 >= 0) {
              long[] gids = cAlignments.getGrouthtruthIDsOfTokenWithSourceID(g.other().left()-1);
              foreach (srcidx; 0..gids.length) {
                auto gid = gids[srcidx];
                if (endsWith(cAlignments[gid].token.byDchar, this.c().p(ARTidx, sidx, g.pred().left()).token)) {
                  cAlignments[gid].prediction_id ~= g.pred().left();
                  if (cAlignments[gid].checked is false) {
                    // TODO: EVAL?
                    cAlignments[gid].checked = true;
                  }
                }
              }
            }
            if (g.other().right() < cAlignments.numTokens()) {
              long[] gids = cAlignments.getGrouthtruthIDsOfTokenWithSourceID(g.other().right());
              foreach (srcidx; 0..gids.length) {
                auto gid = gids[srcidx];
                if (endsWith(cAlignments[gid].token.byDchar, this.c().p(ARTidx, sidx, g.pred().left()).token)) {
                  cAlignments[gid].prediction_id ~= g.pred().left();
                  if (cAlignments[gid].checked is false) {
                    // TODO: EVAL?
                    cAlignments[gid].checked = true;
                  }
                }
              }
            }
            //  ¯\_(ツ)_/¯.
          }
        }
      }
    }

    //
    // Finalisation. Did we forget any alignment index?
    //
    foreach (ARTidx; 0..this.c().numArticles()) {
      foreach (sidx; 0..this.c().numSentences(ARTidx)) {
        bool bFoundUncheckedToken = false;
        auto cAlignments = this.mcCompiler.getAlignment(ARTidx, sidx);
        foreach (tidx; 0..cAlignments.tokens.length) {
          if (cAlignments[tidx].checked is false) {
            bFoundUncheckedToken = true;
            // Some late entries
            this.mcETable[cAlignments[tidx].error_type].detection_fn += 1;
            this.mcETable[cAlignments[tidx].error_type].correction_fn += 1;

            cAlignments[tidx].checked = true;
          }
        }
      }
    }

    //
    // Calculate the suggestion adequacy
    //
    foreach (ARTidx; 0..this.c().numArticles()) {
      foreach (sidx; 0..this.c().numSentences(ARTidx)) {
        auto cAlignments = this.mcCompiler.getAlignment(ARTidx, sidx);
        auto cGaps = this.mcCompiler.getGap(ARTidx, sidx);

        foreach (tidx; 0..cAlignments.tokens.length) {
          auto gid = cAlignments[tidx].id;
          auto sCorr = cAlignments[tidx].correct;
          auto pids = cAlignments[tidx].prediction_id;

          foreach (pid; 0..pids.length) {
            auto suggestions = this.c().p(ARTidx, sidx, pids[pid]).suggestions;

            if (!suggestions.empty) {
              this.mcETable.numSuggestions += 1;

              if (this.c().p(ARTidx, sidx, pids[pid]).token == sCorr) {
                this.mcETable.suggestionAdequacy += 1.0;
              } else if (suggestions.canFind(sCorr)) {
                this.mcETable.suggestionAdequacy += 0.5;
              } else {
                this.mcETable.suggestionAdequacy -= 0.5;
              }
            }
          }
        }
      }
    }

    // Done
  }

  void serializeAlignmentTo(dstring pathToWrite) {
    // this.alignmentTable
    // For each sentence
    string resultFilename = to!string(pathToWrite) ~ "alignments.json";
    std.file.write(resultFilename, "{ \"alignments\": [\n");
    //
    // We are filling the alignments.json through an inverse search
    //
    foreach (ARTidx; 0..this.c().numArticles()) {
      foreach (sidx; 0..this.c().numSentences(ARTidx)) {

        auto cAlignments = this.c().getAlignment(ARTidx, sidx);

        auto predictionTokens = this.c().p(ARTidx, sidx); // Get the predicted tokens


        foreach (pidx; 0..this.c().p().getNumTokens(ARTidx, sidx)) {
          string concatenated_tokens = "";
          string concatenated_sids;
          string concatenated_gids;
          string adequately_corrected;
          ulong[] sidsArray;
          ulong[] gidsArray;
          string[] tokensArray;

          //for (size_t p = 0; p < this.alignmentTable[sidx][aidx].prediction_id.length; ++p) {
          string temp_ = to!string(predictionTokens[pidx].token); //to!string(this.prediction[sidx][this.alignmentTable[sidx][aidx].prediction_id[p]].token);
          if (temp_ == "\"") {
            temp_ = temp_.replace("\"", "\\\"");
          }
          if (temp_ == "\\") {
            temp_ = temp_.replace("\\", "\\\\");
          }
          //}
          tokensArray ~= temp_;

          bool check_helper = true;
          for (size_t aidx = 0; aidx < cAlignments.numTokens(); aidx++) {
            if (cAlignments[aidx].prediction_id.canFind(pidx)) {
              gidsArray ~= cAlignments[aidx].id;
              sidsArray ~= cAlignments[aidx].source_id;
              check_helper = check_helper && cAlignments[aidx].adequately_corrected;
            }
          }
          // Concatenate everything and write to file
          concatenated_tokens = tokensArray.map!(to!string).joiner(" ").to!string;
          if (check_helper == true) {
            adequately_corrected = "true";
          } else {
            adequately_corrected = "false";
          }
          if (sidsArray.length > 0) {
            concatenated_sids = "[" ~ sidsArray.map!(to!string).joiner(",").to!string ~ "]";
          } else {
            concatenated_sids = "[]";
          }
          if (gidsArray.length > 0) {
            concatenated_gids = "[" ~ gidsArray.map!(to!string).joiner(",").to!string ~ "]";
          } else {
            concatenated_gids = "[]";
          }
          string temp = format("  {\"id\": \"a%d.s%d.w%d\", \"token\": \"%s\", \"corrected\": %s, \"gids\": %s, \"sids\": %s },\n",
            ARTidx,
            sidx,
            pidx,
            concatenated_tokens,
            adequately_corrected,
            concatenated_gids,
            concatenated_sids
          );
          if ((ARTidx == (this.c().numArticles() - 1)) &&
              (sidx == (this.c().numSentences(ARTidx) - 1)) &&
              (pidx == (this.c().p().getNumTokens(ARTidx, sidx) - 1))) {
            temp = temp[0..$-2];
          }
          std.file.append(resultFilename, temp);
        }
      }
    }

    std.file.append(resultFilename, "\n  ]\n}");

    //std.file.write(to!string(pathToWrite) ~ "alignments.json", result);
  }

  dstring getResults() {
    writeln("Finalizing results and sending pack to web frontend");
    this.mcETable.finalize();

    // We have the evalTable, all values are normalized etc, no just return the  results as json
    return this.mcETable.asJson();
  }

  /**
   * @brief
   * Returns a reference to the internally used alignment compiler.
   *
   * @return
   * Reference to the internally used alignment compiler.
   */
  private ref AlignmentCompiler c() { return this.mcCompiler; }

  /**
   * @brief
   */
  private GapToken[] generateGapTokenList(GroupAssociation nGroup, long sidx, ref long[] lstAligned, ref GapToken cG) {
    GapToken[] results;
    long range = lstAligned.length / 3;
    foreach (rid; 0..range) {
      // Get the two elements
      auto pid = lstAligned[rid*3];
      auto oid = lstAligned[rid*3+1];
      auto det = lstAligned[rid*3+2];

      //if (det == -1) {
        // Special flag for removing the second token from the gap
      //} else {

      long pL = 0;
      long pR = 0;
      long oL = 0;
      long oR = 0;

      if (rid == 0) { // The first element
        pL = cG.pred().left();
        oL = cG.other().left();
        pR = cG.pred().left() + pid;
        oR = cG.other().left() + oid;
        // Created entry
        if (((pR-pL)==0) && ((oR-oL)==0)) {

        } else {
          results ~= new GapToken(
            nGroup,
            new GapItem(pL, pR, (pR-pL)==0),
            new GapItem(oL, oR, (oR-oL)==0)
          );
        }
      } else { // Everything in between
        auto ppid = lstAligned[(rid-1)*2];
        auto poid = lstAligned[(rid-1)*2+1];
        pL = cG.pred().left()+ppid;
        oL = cG.other().left()+poid;
        pR = cG.pred().left()+pid;
        oR = cG.other().left()+oid;
        // Create entry
        if (((pR-pL)==0) && ((oR-oL)==0)) {

        } else {
          results ~= new GapToken(
            nGroup,
            new GapItem(pL, pR, (pR-pL)==0),
            new GapItem(oL, oR, (oR-oL)==0)
          );
        }
      }

      if (rid == (range - 1)) { // This is also the last element?
        //write("Last element group");
        if (((cG.pred().right()-1) >= pR) ||
            ((cG.other().right-1) >= oR)) {
          if (((cG.pred().right()-pR)==0) && ((cG.other().right()-oR)==0)) {

          } else {
            results ~= new GapToken(
              nGroup,
              new GapItem(pR, cG.pred().right(), (cG.pred().right()-pR)==0),
              new GapItem(oR, cG.other().right(), (cG.other().right()-oR)==0)
            );
          }
        }
      }
      //}
    }

    return results;
  }

  /**
   * @brief
   *
   * @return
   * Returns true if any gap was changed during the process of gap fitting.
   */
  private Tuple!(bool, GapToken[]) postGapFitting(
    ulong aidx,
    long sidx,
    GroupAssociation nGroup,
    ref AlignmentTable cAlignment,
    ref GapToken[] lstGaps,
    long nTolerance = 1
  ) {
    bool changedGapInformation = false;
    long firstUncheckedIdx = -1;

    GapToken[] resultingGaps;

    if (lstGaps.empty) {
      return tuple(changedGapInformation, resultingGaps);
    }
    auto nStartNEndDiff = nTolerance - 1; // -1 because the diff should be 0 in the beginning

    if (nGroup == GroupAssociation.PRD2GRT) {
      //writeln("\t::tResolving P2G");
      foreach (g; lstGaps) {
        ++firstUncheckedIdx;
        if (changedGapInformation) { break; }
        //writeln("\tG: ", g);
        long pLeft = g.pred().left();
        long pRight = g.pred().right();
        long gLeft = g.other().left();
        long gRight = g.other().right();
        auto nDiff = g.diff() * nTolerance; // Handcrafted threshold, maybe replace that later on!
        long[] alignedP2GItems;
        if (g.pred().empty() || g.other().empty()) {
          if (g.other().empty()) {
            // Check the boundaries

            // TODO: Other scenario, e.g. if S: highquality, G: high-quality, P: high high-quality
            //       -> Weird constellation but I've seen such rare cases throughout evaluation

            if (gLeft > 0) {
              // Is the left element within the groundtruth of type REPEAT?
              if (cAlignment[gLeft-1].error_type == ErrorTypes.REPEAT) {
                // If the left is of type REPEAT let's see if this item belongs to the group
                if ((!cAlignment[gLeft-1].prediction_id.canFind(pLeft)) &&
                    ((0 == icmp(cAlignment[gLeft-1].correct.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar)) ||
                    (EvalHelper.sim(cAlignment[gLeft-1].correct.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar) > 0.7))) {
                    //(levenshteinDistance(cAlignment[gLeft-1].correct.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar) <= nDiff))) {
                  // Got it, assign to the repeat
                  cAlignment[gLeft-1].prediction_id ~= pLeft;
                  //alignedP2GItems ~= pLeft;  // NEW
                  //alignedP2GItems ~= gLeft-1; // NEW
                  changedGapInformation = true;
                  break;
                }
              } else if (cAlignment[gLeft-1].error_type == ErrorTypes.SPLIT) {
                // if the left is of type SPLIT let's check if the current items belongs to that split
                // -> Is this item possible the ending of either the groundtruth or source of the left item
                if (endsWith(cAlignment[gLeft-1].correct.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar) ||
                    (EvalHelper.sim(cAlignment[gLeft-1].correct.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar, true) > 0.7) ||
                    endsWith(cAlignment[gLeft-1].token.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar) ||
                    (EvalHelper.sim(cAlignment[gLeft-1].token.byDchar, this.c().p(aidx, sidx, pLeft).token.byDchar, true) > 0.7)) {
                  cAlignment[gLeft-1].prediction_id ~= pLeft;
                  //alignedP2GItems ~= pLeft;  // NEW
                  //alignedP2GItems ~= gLeft-1; // NEW
                  changedGapInformation = true;
                  break;
                }
              } else {
                writeln("In here");
              }

              /*
              if (endsWith(cAlignment[gLeft-1].correct.byDchar, this.c().p()[aidx][sidx][pLeft].token.byDchar)) {
                cAlignment[gLeft-1].prediction_id ~= pLeft;
                alignedP2GItems ~= pLeft;
                alignedP2GItems ~= gLeft-1;
                changedGapInformation = true;
                break;
              }
              if (gRight < cAlignment.numTokens()) {
                if (endsWith(cAlignment[gRight].correct.byDchar, this.c().p()[aidx][sidx][pLeft].token.byDchar)) {
                  cAlignment[gRight].prediction_id ~= pLeft;
                  alignedP2GItems ~= pLeft;
                  alignedP2GItems ~= gRight;
                  changedGapInformation = true;
                break;
                }
              }
              */


              long[] surroundings = cAlignment.getGrouthtruthIDsOfTokenWithPredictionID(gLeft);

              foreach(e; surroundings) {
                if (cAlignment[e].correct.canFind(this.c().p(aidx, sidx, pLeft).token)) {
                  cAlignment[e].prediction_id ~= pLeft;
                  alignedP2GItems ~= pLeft;
                  alignedP2GItems ~= e;
                  changedGapInformation = true;
                  break;
                }
              }
            }
            if ((gRight < cAlignment.numTokens()) && (gRight > 0)) {
              if ((cAlignment[gRight].error_type == ErrorTypes.REPEAT) &&
                  (!cAlignment[gRight].prediction_id.canFind(pRight-1)) &&
                  ((0 == icmp(cAlignment[gRight].correct.byDchar, this.c().p(aidx, sidx, pRight-1).token.byDchar)) ||
                  (EvalHelper.sim(cAlignment[gRight].correct.byDchar, this.c().p(aidx, sidx, pRight-1).token.byDchar) > 0.7) ||
                  (EvalHelper.sim(toLower(cAlignment[gRight].correct.byDchar), toLower(this.c().p(aidx, sidx, pRight-1).token.byDchar)) > 0.7))) {
                  //(levenshteinDistance(cAlignment[gRight].correct.byDchar, this.c().p(aidx, sidx, pRight-1).token.byDchar) <= nDiff))) {
                // Got it, assign to the repeat
                cAlignment[gRight].prediction_id ~= pRight-1;
                alignedP2GItems ~= pRight-1; // NEW
                alignedP2GItems ~= gRight; // NEW
                changedGapInformation = true;
                break;
              }
              /*
              long[] surroundings = cAlignment.getGrouthtruthIDsOfTokenWithPredictionID(gRight);

              foreach(e; surroundings) {
                if (cAlignment[e].correct.canFind(this.c().p(aidx, sidx, pRight-1).token)) {
                  cAlignment[e].prediction_id ~= pRight-1;
                  alignedP2GItems ~= pRight-1;
                  alignedP2GItems ~= e;
                  changedGapInformation = true;
                  break;
                }
              }*/
            }
          } else {
            // Ehm ... there seems to be no element to align the groundtruth token with
            // Let's see if the tool has done something very strange
            // Search the surrounding of the single element and let's try to detect were it belongs to
            //writeln("== DEBUG[SIDX:",sidx,"] ==");
            //writeln("source:", cAlignment[gLeft].token, " :: correct:", cAlignment[gLeft].correct);
            if (pLeft > 0) {
              auto minLength = min(this.c().p(aidx, sidx, pLeft-1).token.length, cAlignment[gLeft].correct.length);
              //writeln("pLeft:", this.c().p()[sidx][pLeft-1].token);
              if (!cAlignment[gLeft].prediction_id.canFind(pLeft-1) &&
                  (EvalHelper.sim(this.c().p(aidx, sidx, pLeft-1).token.byDchar, cAlignment[gLeft].correct[nStartNEndDiff..$].byDchar, true) > 0.7) ||
                  (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft-1).token.byDchar), toLower(cAlignment[gLeft].correct[nStartNEndDiff..$].byDchar), true) > 0.7) ||
                  (EvalHelper.sim(this.c().p(aidx, sidx, pLeft-1).token[$-minLength..$].byDchar, cAlignment[gLeft].correct[minLength..$].byDchar, true) > 0.7) ||
                  (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft-1).token[$-minLength..$].byDchar), toLower(cAlignment[gLeft].correct[minLength..$].byDchar), true) > 0.7)) {
                  //endsWith(this.c().p(aidx, sidx, pLeft-1).token.byDchar, cAlignment[gLeft].correct[nStartNEndDiff..$].byDchar)) {
                cAlignment[gLeft].prediction_id ~= pLeft-1;
                alignedP2GItems ~= pLeft-1;
                alignedP2GItems ~= gLeft;
                alignedP2GItems ~= 0;
                changedGapInformation = true;
                break;
              }
            }
            if (pRight < this.c().p().getNumTokens(aidx, sidx)) {
              auto minLength = min(this.c().p(aidx, sidx, pRight).token.length, cAlignment[gRight-1].correct.length);
              //writeln("pRight:", this.c().p()[sidx][pRight].token);
              if (!cAlignment[gRight-1].prediction_id.canFind(pRight) &&
                  (EvalHelper.sim(this.c().p(aidx, sidx, pRight).token.byDchar, cAlignment[gRight-1].correct[nStartNEndDiff..$].byDchar) > 0.7) ||
                  (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pRight).token.byDchar), toLower(cAlignment[gRight-1].correct[nStartNEndDiff..$].byDchar)) > 0.7) ||
                  (EvalHelper.sim(this.c().p(aidx, sidx, pRight).token[$-minLength..$].byDchar, cAlignment[gRight-1].correct[$-minLength..$].byDchar, true) > 0.7) ||
                  (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pRight).token[$-minLength..$].byDchar), toLower(cAlignment[gRight-1].correct[$-minLength..$].byDchar), true) > 0.7)) {
                  //endsWith(this.c().p(aidx, sidx, pRight).token.byDchar, cAlignment[gRight-1].correct[nStartNEndDiff..$].byDchar)) {
                cAlignment[gRight-1].prediction_id ~= pRight;
                alignedP2GItems ~= pRight;
                alignedP2GItems ~= gRight-1;
                alignedP2GItems ~= 0;
                changedGapInformation = true;
                break;
              }
            }

          }
        } else {
          //writeln("In this branch for :", g);
          //writeln("\tdiffs[nD=",nDiff,"]: g=", g.other().length(), " p=", g.pred().length());
          foreach (pid; 0..g.pred().length()) {
            if (changedGapInformation) { break; }
            foreach (gid; 0..g.other().length()) {
              if (abs(gid-pid) <= nDiff) { // Only when we are within the correct range
                // Do the checking
                // TODO(naetherm): Dynamic difference for levenshtein based on word length?
                long nLevenshteinDiff = to!long(ceil(to!float(cAlignment[gLeft+gid].correct.length) / 2));  // NEW floor -> ceil
                auto minLength = min(cAlignment[gLeft+gid].correct.length, this.c().p(aidx, sidx, pLeft+pid).token.length);
                if ((pLeft+pid < this.c().p(aidx, sidx).getNumTokens()) && (gLeft+gid < cAlignment.numTokens())) {
                  if ((0 == icmp(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct.byDchar)) ||
                      (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct.byDchar) > 0.7) ||
                      (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token.byDchar), toLower(cAlignment[gLeft+gid].correct.byDchar)) > 0.7) ||
                      //(jaroSimilarity(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct.byDchar) >= 0.75) ||
                      //(levenshteinDistance(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct.byDchar) <= nLevenshteinDiff) ||
                      (startsWith(cAlignment[gLeft+gid].correct.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[0..$-nStartNEndDiff].byDchar)) ||
                      (EvalHelper.sim(cAlignment[gLeft+gid].correct.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[0..$-nStartNEndDiff].byDchar) > 0.7) ||
                      (EvalHelper.sim(cAlignment[gLeft+gid].correct[0..minLength].byDchar, this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar) > 0.7) ||
                      (EvalHelper.sim(toLower(cAlignment[gLeft+gid].correct[0..minLength].byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar)) > 0.7) ||
                      (startsWith(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct[0..$-nStartNEndDiff].byDchar)) ||
                      (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct[0..$-nStartNEndDiff].byDchar) > 0.7) ||
                      (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar, cAlignment[gLeft+gid].correct[0..minLength].byDchar) > 0.7) ||
                      (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar), toLower(cAlignment[gLeft+gid].correct[0..minLength].byDchar)) > 0.7) ||
                      (endsWith(cAlignment[gLeft+gid].correct.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[nStartNEndDiff..$].byDchar)) ||
                      (EvalHelper.sim(cAlignment[gLeft+gid].correct.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[nStartNEndDiff..$].byDchar, true) > 0.7) ||
                      (EvalHelper.sim(cAlignment[gLeft+gid].correct[$-minLength..$].byDchar, this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar, true) > 0.7) ||
                      (EvalHelper.sim(toLower(cAlignment[gLeft+gid].correct[$-minLength..$].byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar), true) > 0.7) ||
                      (endsWith(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct[nStartNEndDiff..$].byDchar)) ||
                      (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, cAlignment[gLeft+gid].correct[nStartNEndDiff..$].byDchar, true) > 0.7) ||
                      (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar, cAlignment[gLeft+gid].correct[$-minLength..$].byDchar, true) > 0.7) ||
                      (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar), toLower(cAlignment[gLeft+gid].correct[$-minLength..$].byDchar), true) > 0.7) ||
                      ((this.c().p(aidx, sidx, pLeft+pid).token.length <= 2) ? false : cAlignment[gLeft+gid].correct.canFind(this.c().p(aidx, sidx, pLeft+pid).token)) ||
                      ((this.c().p(aidx, sidx, pLeft+pid).token.length <= 2) ? false : toLower(cAlignment[gLeft+gid].correct).canFind(toLower(this.c().p(aidx, sidx, pLeft+pid).token)))) {
                    // Found a correlation
                    //writeln("Diff is right [P=",pid,", G=",gid,"]...");
                    if (!cAlignment[gLeft+gid].prediction_id.canFind(pLeft+pid)) {
                      //writeln("\tDiff is right [P=",pid,", G=",gid,"]...");
                      cAlignment[gLeft+gid].prediction_id ~= pLeft+pid;
                      alignedP2GItems ~= pid;
                      alignedP2GItems ~= gid;
                      alignedP2GItems ~= 0;
                      changedGapInformation = true;
                      //break;
                    }/* else {
                      // The prediction element is already present! Kick it out
                      alignedP2GItems ~= pid;
                      alignedP2GItems ~= gid;
                      alignedP2GItems ~= -1;
                      changedGapInformation = true;
                      break;
                    }*/
                  }
                }
              }
            }
          }
        }
        // Start the recursive loop
        if (!alignedP2GItems.empty) {
          //writeln("Finally aligned: ", alignedP2GItems);
          // The found alignments are two-padded, the first is the pid, the second the gid
          resultingGaps = this.generateGapTokenList(GroupAssociation.PRD2GRT, sidx, alignedP2GItems, g);
        }
      }

    } else {
      //writeln("\t::tResolving P2S");
      foreach (g; lstGaps) {
        ++firstUncheckedIdx;
        if (changedGapInformation) { break; }
        //writeln("\tG: ", g);
        long pLeft = g.pred().left();
        long pRight = g.pred().right();
        long sLeft = g.other().left();
        long sRight = g.other().right();
        auto nDiff = g.diff() * nTolerance; // Handcrafted threshold, maybe replace that later on!
        long[] alignedP2SItems;
        if (g.pred().empty() || g.other().empty()) {
          // What?!
          if (g.other.empty()) {

            if (sLeft > 0) {

              long[] surroundings = cAlignment.getGrouthtruthIDsOfTokenWithSourceID(sLeft);

              foreach(e; surroundings) {
                if (cAlignment[e].correct.canFind(this.c().p(aidx, sidx, pLeft).token)) {
                  cAlignment[e].prediction_id ~= pLeft;
                  changedGapInformation = true;
                  alignedP2SItems ~= pLeft;
                  alignedP2SItems ~= e;
                  break;
                }
              }


              /*
              if (sLeft-1 >= 0) {
                long[] gids = cAlignment.getGrouthtruthIDsOfTokenWithSourceID(sLeft-1);
                foreach (srcidx; 0..gids.length) {
                  auto gid = gids[srcidx];
                  if (endsWith(cAlignment[gid].token.byDchar, this.c().p()[aidx][sidx][pLeft].token.byDchar)) {
                    cAlignment[gid].prediction_id ~= pLeft;
                    alignedP2SItems ~= pLeft;
                    alignedP2SItems ~= gid;
                    changedGapInformation = true;
                    break;
                  }
                }
              }
              if (sRight < cAlignment.numTokens()) {
                long[] gids = cAlignment.getGrouthtruthIDsOfTokenWithSourceID(sRight);
                foreach (srcidx; 0..gids.length) {
                  auto gid = gids[srcidx];
                  if (endsWith(cAlignment[gid].token.byDchar, this.c().p()[aidx][sidx][pLeft].token.byDchar)) {
                    cAlignment[gid].prediction_id ~= pLeft;
                    alignedP2SItems ~= pLeft;
                    alignedP2SItems ~= gid;
                    changedGapInformation = true;
                    break;
                  }
                }
              }
              */
            }
          }
        } else {
          foreach (pid; 0..g.pred().length()) {
            if (changedGapInformation) { break; }
            foreach (sid; 0..g.other().length()) {
              if (abs(sid-pid) <= nDiff) { // Only when we are within the correct range
                // Do the checking
                long nLevenshteinDiff = to!long(ceil(to!float(this.c().s(aidx, sidx, sLeft+sid).token.length) / 2));
                auto minLength = min(this.c().s(aidx, sidx, sLeft+sid).token.length, this.c().p(aidx, sidx, pLeft+pid).token.length);
                if ((0 == icmp(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token.byDchar)) ||
                    (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token.byDchar) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token.byDchar), toLower(this.c().s(aidx, sidx, sLeft+sid).token.byDchar)) > 0.7) ||
                    (startsWith(this.c().s(aidx, sidx, sLeft+sid).token.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[0..$-nStartNEndDiff].byDchar)) ||
                    (EvalHelper.sim(this.c().s(aidx, sidx, sLeft+sid).token.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[0..$-nStartNEndDiff].byDchar) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().s(aidx, sidx, sLeft+sid).token[0..minLength].byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar)) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().s(aidx, sidx, sLeft+sid).token.byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[0..$-nStartNEndDiff].byDchar)) > 0.7) ||
                    (startsWith(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token[0..$-nStartNEndDiff].byDchar)) ||
                    (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token[0..$-nStartNEndDiff].byDchar) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token[0..minLength].byDchar), toLower(this.c().s(aidx, sidx, sLeft+sid).token[0..minLength].byDchar)) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token.byDchar), toLower(this.c().s(aidx, sidx, sLeft+sid).token[0..$-nStartNEndDiff].byDchar)) > 0.7) ||
                    (endsWith(this.c().s(aidx, sidx, sLeft+sid).token.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[nStartNEndDiff..$].byDchar)) ||
                    (EvalHelper.sim(this.c().s(aidx, sidx, sLeft+sid).token.byDchar, this.c().p(aidx, sidx, pLeft+pid).token[nStartNEndDiff..$].byDchar, true) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().s(aidx, sidx, sLeft+sid).token[$-minLength..$].byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar), true) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().s(aidx, sidx, sLeft+sid).token.byDchar), toLower(this.c().p(aidx, sidx, pLeft+pid).token[nStartNEndDiff..$].byDchar), true) > 0.7) ||
                    (endsWith(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token[nStartNEndDiff..$].byDchar)) ||
                    (EvalHelper.sim(this.c().p(aidx, sidx, pLeft+pid).token.byDchar, this.c().s(aidx, sidx, sLeft+sid).token[nStartNEndDiff..$].byDchar, true) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token[$-minLength..$].byDchar), toLower(this.c().s(aidx, sidx, sLeft+sid).token[$-minLength..$].byDchar), true) > 0.7) ||
                    (EvalHelper.sim(toLower(this.c().p(aidx, sidx, pLeft+pid).token.byDchar), toLower(this.c().s(aidx, sidx, sLeft+sid).token[nStartNEndDiff..$].byDchar), true) > 0.7) ||
                    ((this.c().p(aidx, sidx, pLeft+pid).token.length <= 2) ? false : this.c().s(aidx, sidx, sLeft+sid).token.canFind(this.c().p(aidx, sidx, pLeft+pid).token)) ||
                    ((this.c().p(aidx, sidx, pLeft+pid).token.length <= 2) ? false : toLower(this.c().s(aidx, sidx, sLeft+sid).token).canFind(toLower(this.c().p(aidx, sidx, pLeft+pid).token)))) {
                  // Found a correlation
                  if (cAlignment.appendToPredictionWithSrc(sLeft+sid, pLeft+pid)) {
                    alignedP2SItems ~= pid;
                    alignedP2SItems ~= sid;
                    alignedP2SItems ~= 0;
                    changedGapInformation = true;
                    //break;
                  }
                }
              }
            }
          }
          // Start the recursive loop
          if (!alignedP2SItems.empty) {
            // The found alignments are two-padded, the first is the pid, the second the gid
            resultingGaps = this.generateGapTokenList(GroupAssociation.PRD2SRC, sidx, alignedP2SItems, g);
          }
        }
      }
    }

    // Append the remaining, still unchecked gaps to the list of resulting gaps ...
    resultingGaps ~= lstGaps[firstUncheckedIdx..$];

    return tuple(changedGapInformation, resultingGaps);
  }

  /**
   * The currently used language for this linker.
   */
  Language mcLangDict;

  /**
   * The alignment compiler to instance.
   */
  AlignmentCompiler mcCompiler;

  /**
   * The evaluation table for the final results.
   */
  EvaluationTable mcETable;

}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is the first, obviously simple, sentence.\nAnd another test sentence.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obvisously\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sent-ence\", \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w4\", \"token\": \"sentence\", \"space\": false},
      {\"id\": \"a0.s1.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"first\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"obviously\", \"type\": \"NON_WORD\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \"simple\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"sentence\", \"type\": \"HYPHENATION\" },
      {\"affected-id\": \"a0.s0.w9\", \"correct\": \".\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w0\", \"correct\": \"And\", \"type\": \"CAPITALISATION\" },
      {\"affected-id\": \"a0.s1.w1\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w2-a0.s1.w3\", \"correct\": \"test\", \"type\": \"REPEAT\" },
      {\"affected-id\": \"a0.s1.w4\", \"correct\": \"sentence\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [2]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obviously\", \"suggestions\": [\"obvisously\", \"obvious\"], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"suggestions\": [\"sample\"], \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sequence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"And\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"test\", \"suggestions\": [\"test\"], \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"test\", \"suggestions\": [\"test\"], \"space\": true},
      {\"id\": \"a0.s1.w4\", \"token\": \"sentence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w5\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize(readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is the first, obviously simple, sentence.\nAnd another test sentence.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obvisously\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sent-ence\", \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w4\", \"token\": \"sentence\", \"space\": false},
      {\"id\": \"a0.s1.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"first\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"obviously\", \"type\": \"NON_WORD\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \"simple\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"sentence\", \"type\": \"HYPHENATION\" },
      {\"affected-id\": \"a0.s0.w9\", \"correct\": \".\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w0\", \"correct\": \"And\", \"type\": \"CAPITALISATION\" },
      {\"affected-id\": \"a0.s1.w1\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w2-a0.s1.w3\", \"correct\": \"test\", \"type\": \"REPEAT\" },
      {\"affected-id\": \"a0.s1.w4\", \"correct\": \"sentence\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [2]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obviously\", \"suggestions\": [\"obvisously\", \"obvious\"], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"suggestions\": [\"sample\"], \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sequence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"And\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"test\", \"suggestions\": [\"test\"], \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"sentence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w4\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize(readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is the first, obviously simple, sentence.\nAnd another test sentence.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obvisously\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sent-ence\", \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s1.w4\", \"token\": \"sentence\", \"space\": false},
      {\"id\": \"a0.s1.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"first\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"obviously\", \"type\": \"NON_WORD\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \"simple\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"sentence\", \"type\": \"HYPHENATION\" },
      {\"affected-id\": \"a0.s0.w9\", \"correct\": \".\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w0\", \"correct\": \"And\", \"type\": \"CAPITALISATION\" },
      {\"affected-id\": \"a0.s1.w1\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w2-a0.s1.w3\", \"correct\": \"test\", \"type\": \"REPEAT\" },
      {\"affected-id\": \"a0.s1.w4\", \"correct\": \"sentence\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s1.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [2]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obstacle\", \"suggestions\": [\"obvisously\", \"obvious\"], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"sample\", \"suggestions\": [\"sample\"], \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sequence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w0\", \"token\": \"And\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w1\", \"token\": \"another\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s1.w2\", \"token\": \"text\", \"suggestions\": [\"test\"], \"space\": true},
      {\"id\": \"a0.s1.w3\", \"token\": \"sentence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s1.w4\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize(readInfo[0], readInfo[1], readInfo[2]);

  linker.build();
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"case\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"test\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"case\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"an\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"other\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"text\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"case\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize(readInfo[0], readInfo[1], readInfo[2]);

  linker.build();
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"case\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"test\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"case\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Thss\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"as\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"otter\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"test\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"care\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();
}
unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  dstring raw_demo = "This is the first, obviously simple, sentence.\nAnd another test sentence.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obvisously\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"simple\", \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sent-ence\", \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"space\": false},
      {\"id\": \"a1.s0.w0\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a1.s0.w1\", \"token\": \"another\", \"space\": true},
      {\"id\": \"a1.s0.w2\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a1.s0.w3\", \"token\": \"test\", \"space\": true},
      {\"id\": \"a1.s0.w4\", \"token\": \"sentence\", \"space\": false},
      {\"id\": \"a1.s0.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"This\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"is\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"first\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"obviously\", \"type\": \"NON_WORD\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \"simple\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"sentence\", \"type\": \"HYPHENATION\" },
      {\"affected-id\": \"a0.s0.w9\", \"correct\": \".\", \"type\": \"NONE\" },
      {\"affected-id\": \"a1.s0.w0\", \"correct\": \"And\", \"type\": \"CAPITALISATION\" },
      {\"affected-id\": \"a1.s0.w1\", \"correct\": \"another\", \"type\": \"NONE\" },
      {\"affected-id\": \"a1.s0.w2-a1.s0.w3\", \"correct\": \"test\", \"type\": \"REPEAT\" },
      {\"affected-id\": \"a1.s0.w4\", \"correct\": \"sentence\", \"type\": \"NONE\" },
      {\"affected-id\": \"a1.s0.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 2,
      \"sentences\": [1, 1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"This\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"is\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"first\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"obstacle\", \"suggestions\": [\"obvisously\", \"obvious\"], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"sample\", \"suggestions\": [\"sample\"], \"space\": false},
      {\"id\": \"a0.s0.w7\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"sequence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w9\", \"token\": \".\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a1.s0.w0\", \"token\": \"And\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a1.s0.w1\", \"token\": \"another\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a1.s0.w2\", \"token\": \"text\", \"suggestions\": [\"test\"], \"space\": true},
      {\"id\": \"a1.s0.w3\", \"token\": \"sentence\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a1.s0.w4\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize(readInfo[0], readInfo[1], readInfo[2]);

  linker.build();
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  //dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Gerti\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"reveals\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"she\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"sabotaged\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"it\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"Gerti\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"reveals\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"she\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"sabotaged\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"it\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Ger\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"ti\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"reveals\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"she\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"sabotaged\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"it\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();

  writeln("========================================");
}



unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  writeln("SOON AFTERWARDS ...");

  dstring raw_demo = "This is the first, obviously simple, sentence.\nAnd another test sentence.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Soon\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"afterwards\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"Curtis\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"reverted\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"her\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"ring\", \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \"name\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"tog\", \"space\": true},
      {\"id\": \"a0.s0.w9\", \"token\": \"Jo\", \"space\": true},
      {\"id\": \"a0.s0.w10\", \"token\": \"hnny\", \"space\": true},
      {\"id\": \"a0.s0.w11\", \"token\": \"Curtis\", \"space\": true},
      {\"id\": \"a0.s0.w12\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"Soon\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"afterwards\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"Curtis\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"revertex\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"his\", \"type\": \"NON_WORD\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \"ring\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \"name\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"to\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w9-a0.s0.w10\", \"correct\": \"Johnny\", \"type\": \"SPLIT\" },
      {\"affected-id\": \"a0.s0.w11\", \"correct\": \"Curtis\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w12\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [2]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Soon\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"afterwards\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"Curtis\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"reverted\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"his\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"ring\", \"suggestions\": [\"sample\"], \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \"name\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"tog\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w9\", \"token\": \"Jo\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w10\", \"token\": \"hnny\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w11\", \"token\": \"Curtis\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w12\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  writeln("On the January 4, 2012, episode of \"NXT Redepmtion\", Curtis and Maxine revealed");

  dstring raw_demo = "On the January 4, 2012, episode of \"NXT Redepmtion\", Curtis and Maxine revealed";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"On\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"January\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"4\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"2012\", \"space\": false},
      {\"id\": \"a0.s0.w6\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \"episode\", \"space\": true},
      {\"id\": \"a0.s0.w8\", \"token\": \"of\", \"space\": true},
      {\"id\": \"a0.s0.w9\", \"token\": \"\\\"\", \"space\": false},
      {\"id\": \"a0.s0.w10\", \"token\": \"NXT\", \"space\": true},
      {\"id\": \"a0.s0.w11\", \"token\": \"Redemption\", \"space\": false},
      {\"id\": \"a0.s0.w12\", \"token\": \"\\\"\", \"space\": false},
      {\"id\": \"a0.s0.w13\", \"token\": \",\", \"space\": true},
      {\"id\": \"a0.s0.w14\", \"token\": \"Curtis\", \"space\": true},
      {\"id\": \"a0.s0.w15\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a0.s0.w16\", \"token\": \"Maxine\", \"space\": true},
      {\"id\": \"a0.s0.w17\", \"token\": \"revealed\", \"space\": true},
      {\"id\": \"a0.s0.w18\", \"token\": \"that\", \"space\": true},
      {\"id\": \"a0.s0.w19\", \"token\": \"they\", \"space\": true},
      {\"id\": \"a0.s0.w20\", \"token\": \"would\", \"space\": true},
      {\"id\": \"a0.s0.w21\", \"token\": \"marry\", \"space\": true},
      {\"id\": \"a0.s0.w22\", \"token\": \"in\", \"space\": true},
      {\"id\": \"a0.s0.w23\", \"token\": \"two\", \"space\": true},
      {\"id\": \"a0.s0.w24\", \"token\": \"weeks\", \"space\": true},
      {\"id\": \"a0.s0.w25\", \"token\": \"time\", \"space\": true},
      {\"id\": \"a0.s0.w26\", \"token\": \"in\", \"space\": true},
      {\"id\": \"a0.s0.w27\", \"token\": \"Las\", \"space\": true},
      {\"id\": \"a0.s0.w28\", \"token\": \"Vegas\", \"space\": true},
      {\"id\": \"a0.s0.w29\", \"token\": \"during\", \"space\": true},
      {\"id\": \"a0.s0.w30\", \"token\": \"Bateman's\", \"space\": true},
      {\"id\": \"a0.s0.w31\", \"token\": \"match\", \"space\": true},
      {\"id\": \"a0.s0.w32\", \"token\": \"with\", \"space\": true},
      {\"id\": \"a0.s0.w33\", \"token\": \"Darren\", \"space\": true},
      {\"id\": \"a0.s0.w34\", \"token\": \"Young\", \"space\": false},
      {\"id\": \"a0.s0.w35\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"On\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"January\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"4\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"2012\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w7\", \"correct\": \"episode\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w8\", \"correct\": \"of\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w9\", \"correct\": \"\\\"\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w10\", \"correct\": \"NXT\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w11\", \"correct\": \"Redemption\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w12\", \"correct\": \"\\\"\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w13\", \"correct\": \",\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w14\", \"correct\": \"Curtis\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w15\", \"correct\": \"and\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w16\", \"correct\": \"Maxine\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w17\", \"correct\": \"revealed\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w18\", \"correct\": \"that\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w19\", \"correct\": \"they\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w20\", \"correct\": \"would\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w21\", \"correct\": \"marry\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w22\", \"correct\": \"in\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w23\", \"correct\": \"two\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w24\", \"correct\": \"weeks\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w25\", \"correct\": \"time\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w26\", \"correct\": \"in\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w27\", \"correct\": \"Las\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w28\", \"correct\": \"Vegas\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w29\", \"correct\": \"during\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w30\", \"correct\": \"Bateman's\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w31\", \"correct\": \"match\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w32\", \"correct\": \"with\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w33\", \"correct\": \"Darren\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w34\", \"correct\": \"Young\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w35\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"On\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"January\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"4\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w3\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"2012\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w5\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"episode\", \"suggestions\": [\"sample\"], \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \"of\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w8\", \"token\": \"\\\"\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w9\", \"token\": \"NXT\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w10\", \"token\": \"Redemption\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w11\", \"token\": \"\\\"\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w12\", \"token\": \",\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w13\", \"token\": \"Curtis\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w14\", \"token\": \"and\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w15\", \"token\": \"Maxine\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w16\", \"token\": \"revealed\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w17\", \"token\": \"that\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w18\", \"token\": \"they\", \"suggestions\": [\"sample\"], \"space\": true},
      {\"id\": \"a0.s0.w19\", \"token\": \"would\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w20\", \"token\": \"marry\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w21\", \"token\": \"in\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w22\", \"token\": \"two\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w23\", \"token\": \"weeks\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w24\", \"token\": \"'\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w25\", \"token\": \"time\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w26\", \"token\": \"in\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w27\", \"token\": \"Las\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w28\", \"token\": \"Vegas\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w29\", \"token\": \"during\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w30\", \"token\": \"Bateman's\", \"suggestions\": [\"sample\"], \"space\": true},
      {\"id\": \"a0.s0.w31\", \"token\": \"match\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w32\", \"token\": \"with\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w33\", \"token\": \"Darren\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w34\", \"token\": \"Young\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w35\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  //dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Gerti\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"reveals\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"she\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"sabo\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"taged\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"it\", \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"Gerti\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"reveals\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"she\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3-a0.s0.w4\", \"correct\": \"sabotaged\", \"type\": \"SPLIT\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"it\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w6\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Ger\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"ti\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"reveals\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"shesabo\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"tagged\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"it\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w7\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();

  writeln("========================================");
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  //dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"The\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"The\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"The\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"The\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"The\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"The\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"The\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"The\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"T\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"he\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"T\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"he\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"T\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"he\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w6\", \"token\": \"The\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();

  writeln("========================================");
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  //dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"into\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"teleprompter\", \"space\": false},
      {\"id\": \"a0.s0.w3\", \"token\": \"which\", \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"The\", \"space\": true},
      {\"id\": \"a0.s0.w5\", \"token\": \"President\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"into\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"teleprompter\", \"type\": \"CONCATENATION\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"which\", \"type\": \"CONCATENATION\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \"President\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"into\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"teleprompter-which\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"The\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w4\", \"token\": \"President\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();

  writeln("========================================");
}

unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

  //dstring raw_demo = "This is another test case.";
  dstring source_demo = "{
    \"tokens\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Team\", \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"and\", \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"Fun\", \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \"Club\", \"space\": false},
      {\"id\": \"a0.s0.w5\", \"token\": \".\", \"space\": false}
    ]
  }";
  dstring groundtruth_demo = "
  {
    \"corrections\": [
      {\"affected-id\": \"a0.s0.w0\", \"correct\": \"Team\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w1\", \"correct\": \"and\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w2\", \"correct\": \"the\", \"type\": \"NONE\" },
      {\"affected-id\": \"a0.s0.w3\", \"correct\": \"Fun\", \"type\": \"CONCATENATION\" },
      {\"affected-id\": \"a0.s0.w4\", \"correct\": \"Club\", \"type\": \"CONCATENATION\" },
      {\"affected-id\": \"a0.s0.w5\", \"correct\": \".\", \"type\": \"NONE\" }
    ],
    \"information\": {
      \"numArticles\": 1,
      \"sentences\": [1]
    }
  }";
  dstring prediction_demo = "{
    \"predictions\": [
      {\"id\": \"a0.s0.w0\", \"token\": \"Team\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w1\", \"token\": \"and\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w2\", \"token\": \"the\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w3\", \"token\": \"FanClub\", \"suggestions\": [], \"space\": false},
      {\"id\": \"a0.s0.w4\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentLinker linker = new AlignmentLinker(lang_dummy);

  linker.initialize( readInfo[0], readInfo[1], readInfo[2]);

  linker.build();

  linker.evaluate();

  writeln("========================================");
}
