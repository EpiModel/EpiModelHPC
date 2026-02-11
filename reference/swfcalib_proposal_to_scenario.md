# Convert an swfcalib Proposal into an EpiModel Scenario

Convert an swfcalib Proposal into an EpiModel Scenario

## Usage

``` r
swfcalib_proposal_to_scenario(proposal, id = NULL)
```

## Arguments

- proposal:

  an swfcalib formatted proposal

- id:

  the `.scenario.id` for the scenario. If `NULL`, use the
  `.proposal_index` or "default" if the former is `NULL` as well.

## Value

an EpiModel scenario
