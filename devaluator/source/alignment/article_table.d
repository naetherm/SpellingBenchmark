// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.article_table;

import devaluator.alignment.alignment_table;

/** 
 * @class
 * ArticleTable
 * 
 * A collection of sentences.
 */
class ArticleTable {
  /** 
   * Constructor.
   * Params:
   *   nNumArticles = The amount of articles.
   */
  this(ulong nNumArticles) {
    // Create and initialize 
    this.initialize(nNumArticles);
  }

  /** 
   * Just clear the internal used information.
   */
  void clear() {
    this.mlstArticles.destroy();
  }

  void initialize(ulong nNumArticles) {
    // First cleanup
    this.mlstArticles.destroy();
    // Now initialize the internally used tables
    foreach(aidx; 0..nNumArticles) {
      this.mlstArticles[aidx] = new AlignmentTable();
    }
  }


  /** 
   * Returns a reference to the article information of the article at position nIdx.
   * Params:
   *   nIdx = The index position of the article information that should be returned.
   * Returns: Reference to the article information.
   */
  ref AlignmentTable getArticleInformation(ulong nIdx) {
    return this.mlstArticles[nIdx];
  }

  /** 
   * Returns a reference to the article information of the article at position nIdx.
   * Params:
   *   nIdx = The index position of the article information that should be returned.
   * Returns: Reference to the article information.
   */
  ref AlignmentTable a(ulong nIdx) {
    return this.mlstArticles[nIdx];
  }

  /** 
   * List containing all articles. This is a associative list ID -> Article-Information.
   */
  AlignmentTable[ulong] mlstArticles;
}