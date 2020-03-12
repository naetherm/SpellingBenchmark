// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.alignment_compiler;

import std.algorithm;
import std.string;
import std.stdio;

import devaluator.alignment.zero_cut_alignment: ZeroCutAlignment, Result;
import devaluator.alignment.alignment_table;
import devaluator.alignment.gap_table;
import devaluator.utils.helper;
import devaluator.utils.types;

/**
 * @class
 * AlignmentCompiler
 *
 * @brief
 */
class AlignmentCompiler {

  /**
   * @brief
   * Constructor.
   */
  this(ref GroundtruthRepr cGroundtruth, ref PredictionRepr cPrediction, ref SourceRepr cSource) {
    this.mcGroundtruth = cGroundtruth;
    this.mcPrediction = cPrediction;
    this.mcSource = cSource;
  }

  /**
   * @brief
   * Simply responsible for the cleanup of all datastructures.
   */
  void clear() {
    this.mlstGapTable.destroy();
    this.mlstAlignmentTable.destroy();
    this.mcSource.destroy();
    this.mcPrediction.destroy();
    this.mcGroundtruth.destroy();
  }

  ulong numArticles() {
    return this.mcGroundtruth.numArticles();
  }

  ulong numSentences(ulong aidx) {
    return this.mcGroundtruth.numSentences(aidx);
  }

  ref AlignmentTable getAlignment(ulong aidx, ulong nIdx) {
    return this.mlstAlignmentTable[aidx].sentences[nIdx];
  }

  ref GapTable getGap(ulong aidx, ulong nIdx) {
    return this.mlstGapTable[aidx].sentences[nIdx];
  }

  ref SourceRepr s() { return this.mcSource; }

  ref PredictionRepr p() { return this.mcPrediction; }

  ref GroundtruthRepr g() { return this.mcGroundtruth; }

  ref TArticle!(SourceSentence) s(ulong aidx) { return this.mcSource[aidx]; }

  ref TArticle!(PredictionSentence) p(ulong aidx) { return this.mcPrediction[aidx]; }

  ref TArticle!(GroundtruthSentence) g(ulong aidx) { return this.mcGroundtruth[aidx]; }

  ref SourceSentence s(ulong aidx, ulong sidx) { return this.mcSource[aidx][sidx]; }

  ref PredictionSentence p(ulong aidx, ulong sidx) { return this.mcPrediction[aidx][sidx]; }

  ref GroundtruthSentence g(ulong aidx, ulong sidx) { return this.mcGroundtruth[aidx][sidx]; }

  ref SourceToken s(ulong aidx, ulong sidx, ulong tidx) { return this.mcSource[aidx][sidx][tidx]; }

  ref PredictionToken p(ulong aidx, ulong sidx, ulong tidx) { return this.mcPrediction[aidx][sidx][tidx]; }

  ref GroundtruthToken g(ulong aidx, ulong sidx, ulong tidx) { return this.mcGroundtruth[aidx][sidx][tidx]; }

  void build() {
    ulong numArticles = this.mcGroundtruth.numArticles();
    foreach(a; 0..numArticles) {
      // get the number of sentences so that we can pre-allocate all required structures
      ulong nNumSentences = this.mcGroundtruth.numSentences(a);

      // 0) First, cleanup
      //this.clear();

      // 1) Pre-initialize all tables
      this.initialize(a, nNumSentences);

      // 2) Pre-populate all tables
      this.prepopulate(a, nNumSentences);

      // 3) Alignment between groundtruth and prediction
      this.alignment(a, nNumSentences);

      this.logicalInverseAssign(a, nNumSentences);
    }
  }

  private void initialize(ulong aidx, ulong nNumSentences) {
    // initialize the article tables first
    this.mlstAlignmentTable[aidx] = new AlignmentArticle();
    this.mlstGapTable[aidx] = new GapArticle();
    foreach (sidx; 0..nNumSentences) {
      // Initialize the intern structures for the alignment and gap information
      this.mlstAlignmentTable[aidx].sentences[sidx] = new AlignmentTable();
      this.mlstGapTable[aidx].sentences[sidx] = new GapTable();
      // Prepopulate with the number of possible tokens
      this.mlstAlignmentTable[aidx].sentences[sidx].preallocate(this.mcGroundtruth.getNumTokensForSentence(aidx, sidx));
    }
  }

  /**
   * @brief
   * This method will prepopulate the most important data and information of the alignment table.
   *
   * @param [in]nNumSentences
   * The amount of sentences within the current evaluation.
   */
  private void prepopulate(ulong aidx, ulong nNumSentences) {
    foreach (sidx; 0..nNumSentences) {
      foreach (tidx; 0..this.mlstAlignmentTable[aidx].sentences[sidx].numTokens()) {
        this.mlstAlignmentTable[aidx].sentences[sidx].getToken(tidx).id = this.mcGroundtruth.getToken(aidx, sidx, tidx).id;
        this.mlstAlignmentTable[aidx].sentences[sidx].getToken(tidx).source_id = this.mcGroundtruth.getToken(aidx, sidx, tidx).source_ids.dup;
        this.mlstAlignmentTable[aidx].sentences[sidx].getToken(tidx).token = this.mcGroundtruth.getToken(aidx, sidx, tidx).source_token.dup;
        this.mlstAlignmentTable[aidx].sentences[sidx].getToken(tidx).correct = this.mcGroundtruth.getToken(aidx, sidx, tidx).target_token.dup;
        this.mlstAlignmentTable[aidx].sentences[sidx].getToken(tidx).error_type = this.mcGroundtruth.getToken(aidx, sidx, tidx).error_type;
      }
    }
  }

  /**
   * @brief
   * This method is responsible for building the alignments between all three representations:
   * groundtruth, prediction, and source.
   *
   * In subsequent steps we build the alignment tables between all of these representations
   * and merge the gaps to gap-groups
   */
  private void alignment(ulong aidx, ulong nNumSentences) {
    // Loop through all sentences
    foreach (sidx; 0..nNumSentences) {
      // Fetch all tokens of the current sentence. We are doing some cheating right here, which
      // makes the alignment building a bit more "efficient" by making usage of case insensitivity
      dstring[] s_tokens = this.mcSource.getTokens(aidx, sidx);
      dstring[] p_tokens = this.mcPrediction.getTokens(aidx, sidx);
      dstring[] g_tokens = this.mcGroundtruth.getTokens(aidx, sidx);
      foreach (i; 0 .. s_tokens.length) { s_tokens[i] = s_tokens[i].toLower(); }
      foreach (i; 0 .. p_tokens.length) { p_tokens[i] = p_tokens[i].toLower(); }
      foreach (i; 0 .. g_tokens.length) { g_tokens[i] = g_tokens[i].toLower(); }
      // Build alignment between prediction and groundtruth
      auto cP2G_ZCA = new ZeroCutAlignment!(dstring)(p_tokens, g_tokens);
      Result cP2GRes = cP2G_ZCA.build();

      writeln("cP2GRes[0]: ");
      foreach(i; 0..cP2GRes[0].length) {
        writeln(cP2GRes[0][i]);
      }
      writeln("cP2GRes[1]: ");
      foreach(i; 0..cP2GRes[1].length) {
        writeln(cP2GRes[1][i]);
      }

      // Build alignment between prediction and source
      auto cP2S_ZCA = new ZeroCutAlignment!(dstring)(p_tokens, s_tokens);
      Result cP2SRes = cP2S_ZCA.build();

      writeln("cP2SRes[0]: ");
      foreach(i; 0..cP2SRes[0].length) {
        writeln(cP2SRes[0][i]);
      }
      writeln("cP2SRes[1]: ");
      foreach(i; 0..cP2SRes[1].length) {
        writeln(cP2SRes[1][i]);
      }

      // Merge everything
      this.merge(aidx, sidx, cP2GRes, cP2SRes);

      // Resolve gap information
      this.gapify(aidx, sidx, cP2GRes, cP2SRes);
    }
  }

  /**
   * @brief
   * This last step tries to stuff some remaining gaps before we go to the linking process.
   * What we are doing in here:
   * Loop through all P2S gaps:
   *   For each sid in the gap find the correlating groundtruth token and check whether
   *     it is within the list of pids of that gap if it has any connection to P.
   *   If true make that connection betwen P and S and
   */
  void logicalInverseAssign(ulong aidx, ulong nNumSentences) {
    foreach (nSent; 0..nNumSentences) {
      bool bHasAnythingChanged = false;
      do {
        bHasAnythingChanged = false;
        GapToken[] newP2SGaps;
        foreach (gidx; 0..this.mlstGapTable[aidx].sentences[nSent].lengthP2S()) {
          auto gap = this.mlstGapTable[aidx].sentences[nSent].p2sAt(gidx);

          bool bHasGapChanged = false;

          // Only proceed if we can get any information about the source alignment
          if (!gap.other().empty()) {
            auto pLeft = gap.pred().left();
            auto pRight = gap.pred().right();
            auto sLeft = gap.other().left();
            auto sRight = gap.other().right();

            foreach(sidx; sLeft..sRight) {
              if (bHasGapChanged) { break;}
              long[] gids = this.mlstAlignmentTable[aidx].sentences[nSent].getGrouthtruthIDsOfTokenWithSourceID(sidx);

              foreach (gid; gids) {
                if (bHasGapChanged) { break; }
                if ([ErrorTypes.SPLIT, ErrorTypes.REPEAT, ErrorTypes.CONCATENATION].canFind(
                  this.mlstAlignmentTable[aidx][nSent][gid].error_type) == false) {
                  foreach (pid; this.mlstAlignmentTable[aidx][nSent][gid].prediction_id) {
                    if ((pLeft <= pid) && (pRight > pid)) {
                      writeln("Found Association: P[", pLeft, ":",pid,":",pRight,"]=>S[",sLeft,":",sidx,":",sRight,"]");
                      // Found something, this source token is resolved but we have to remove that gap item and create some new ones
                      if ((sidx != sLeft) || (pid != pLeft)) {
                        newP2SGaps ~= new GapToken(
                          GroupAssociation.PRD2SRC,
                          new GapItem(
                            pLeft, pid, pLeft == pid
                          ),
                          new GapItem(
                            sLeft, sidx, sLeft == sidx
                          )
                        );
                      }

                      if ((sidx+1 <= sRight-1) || (pid+1 <= pRight-1)) {
                        newP2SGaps ~= new GapToken(
                          GroupAssociation.PRD2SRC,
                          new GapItem(
                            pid+1,
                            pRight,
                            (pid+1) == (pRight-1)
                          ),
                          new GapItem(
                            sidx+1,
                            sRight,
                            (sidx+1) == (sRight-1)
                          )
                        );
                      }

                      bHasGapChanged = true;
                      bHasAnythingChanged = true;
                      break;
                    }
                  }
                }
              }
            }
          }

          // The gap hasn't changed, so simple add it again
          if (!bHasGapChanged) {
            newP2SGaps ~= gap;
          }
        }

        if (bHasAnythingChanged) {
          // Okay, damn: Cleanup
          this.mlstGapTable[aidx].sentences[nSent].replaceGapTokens(GroupAssociation.PRD2SRC, newP2SGaps);
        }
      } while (bHasAnythingChanged);
    }
  }

  /**
   * @brief
   * This method will merge the fetch information for the sentence @p nSentence.
   * Keep in midn that the additional parameters will hold the data within the following format:
   * -  cP2G: The first element of each group are the IDs of the prediction, the second for the
   *    groundtruth.
   * -  cP2S: The first element of each group are the IDs of the prediction, the second for the
   *    source.
   */
  private void merge(ulong aidx, ulong nSentence, ref Result cP2G, ref Result cP2S) {
    // First, loop through all entires of P2G[0] (The real alignment information)
    // We can just the fact that both, the prediction and the groundtruth must have the same length here
    // otherwise an n-gram alignment wouldn't have been possible!
    // The assignment is pretty easy here because the alignment table is groundtruth-centric so we simply
    // make a reverse assignment.
    foreach (gidx; 0..cP2G[0].length) {
      foreach(sidx; 0..cP2G[0][gidx].length()) {
        this.mlstAlignmentTable[aidx].sentences[nSentence][cP2G[0][gidx].second().mnLeft+sidx].prediction_id ~= cP2G[0][gidx].first().mnLeft+sidx;
      }
    }

    // Second, loop through all entries of P2S[0] (The real alignment information)
    // We can just the fact that both, the prediction and the source must have the same length here
    // otherwise an n-gram alignment wouldn't have been possible!
    // In contrast to the previous assignment we cannot directly assign the labels, we have to loop
    // through the whole table to find the groundtruth-entry which owns the correct source id
    foreach (gidx; 0..cP2S[0].length) {
      foreach(sidx; 0..cP2S[0][gidx].length()) {
        this.mlstAlignmentTable[aidx].sentences[nSentence].appendToPredictionWithSrc(cP2S[0][gidx].second().mnLeft+sidx, cP2S[0][gidx].first().mnLeft+sidx);
      }
    }

    // Uniquify the prediction lists
    this.mlstAlignmentTable[aidx].sentences[nSentence].makeUnique();

    //writeln("Resulting AlignmentTable:");
    //writeln(this.mlstAlignmentTable[nSentence]);
  }

  private void gapify(ulong aidx, ulong nSentence, ref Result cP2G, ref Result cP2S) {
    foreach (gidx; 0..cP2G[1].length) {
      this.mlstGapTable[aidx].sentences[nSentence].add(
        new GapToken(
          GroupAssociation.PRD2GRT,
          new GapItem(
            cP2G[1][gidx].mcFirst.mnLeft,
            cP2G[1][gidx].mcFirst.mnRight,
            cP2G[1][gidx].mcFirst.mnLeft == cP2G[1][gidx].mcFirst.mnRight), // Prediction
          new GapItem(
            cP2G[1][gidx].mcSecond.mnLeft,
            cP2G[1][gidx].mcSecond.mnRight,
            cP2G[1][gidx].mcSecond.mnLeft == cP2G[1][gidx].mcSecond.mnRight) // Groundtruth
        )
      );
    }

    foreach (gidx; 0..cP2S[1].length) {
      this.mlstGapTable[aidx].sentences[nSentence].add(
        new GapToken(
          GroupAssociation.PRD2SRC,
          new GapItem(
            cP2S[1][gidx].mcFirst.mnLeft,
            cP2S[1][gidx].mcFirst.mnRight,
            cP2S[1][gidx].mcFirst.mnLeft == cP2S[1][gidx].mcFirst.mnRight), // Prediction
          new GapItem(
            cP2S[1][gidx].mcSecond.mnLeft,
            cP2S[1][gidx].mcSecond.mnRight,
            cP2S[1][gidx].mcSecond.mnLeft == cP2S[1][gidx].mcSecond.mnRight) // Source
        )
      );
    }

    //writeln("Resulting GapTable:");
    //writeln(this.mlstGapTable[nSentence]);
  }

  /**
   * The groundtruth information
   */
  GroundtruthRepr mcGroundtruth;
  /**
   * The prediction information
   */
  PredictionRepr mcPrediction;
  /**
   * The source information
   */
  SourceRepr mcSource;

  /**
   * The generated alignment information between groundtruth, prediction, and source.
   */
  AlignmentArticle[ulong] mlstAlignmentTable;
  /**
   * The generated gap information between groundtruth, prediction, and source.
   */
  GapArticle[ulong] mlstGapTable;
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
      {\"id\": \"a0.s0.w8\", \"token\": \"sentence\", \"suggestions\": [], \"space\": false},
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

  AlignmentCompiler compiler = new AlignmentCompiler(readInfo[1], readInfo[2], readInfo[0]);

  compiler.build();

}


unittest {

  import devaluator.utils.helper: RawRepr, PredictionRepr, GroundtruthRepr, SourceRepr;
  import devaluator.utils.data_reader: DataReader, JSONDataReader;
  import devaluator.utils.language: Language;

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
      {\"id\": \"a0.s0.w8\", \"token\": \"to\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w9\", \"token\": \"Johnny\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w10\", \"token\": \"Curtis\", \"suggestions\": [], \"space\": true},
      {\"id\": \"a0.s0.w11\", \"token\": \".\", \"suggestions\": [], \"space\": false}
    ]
  }";

  Language lang_dummy = new Language();

  DataReader reader = new DataReader();

  auto readInfo = reader.parse(source_demo, groundtruth_demo, prediction_demo);

  AlignmentCompiler compiler = new AlignmentCompiler(readInfo[1], readInfo[2], readInfo[0]);

  compiler.build();

}
