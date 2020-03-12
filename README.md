# SpellingCorrectionBenchmark

Benchmark and Evaluation metrics for the task of spelling error detection and correction.

## Usage

Note: You will need docker-compose installed on your machine.

### Quick Example

Just use docker-compose (keep in mind that we will need access to the university network to receive the wikipedia dataset from ```/nfs/datasets/```, the creating of the raw wikipedia data would take approx. a day):

```
docker-compose build web && docker-compose up web
```

