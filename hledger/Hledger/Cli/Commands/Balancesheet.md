## balancesheet

(bs)

This command displays a [balance sheet](https://en.wikipedia.org/wiki/Balance_sheet), 
showing historical ending balances of asset and liability accounts. 
(To see equity as well, use the [balancesheetequity](#balancesheetequity) command.)
Amounts are shown with normal positive sign, as in conventional
financial statements.

_FLAGS

This report shows accounts declared with the `Asset`, `Cash` or `Liability` type
(see [account types](https://hledger.org/hledger.html#account-types)).
Or if no such accounts are declared, it shows top-level accounts named
`asset` or `liability` (case insensitive, plurals allowed) and their subaccounts.

Example:

```shell
$ hledger balancesheet
Balance Sheet

Assets:
                 $-1  assets
                  $1    bank:saving
                 $-2    cash
--------------------
                 $-1

Liabilities:
                  $1  liabilities:debts
--------------------
                  $1

Total:
--------------------
                   0
```

This command is a higher-level variant of the [`balance`](#balance) command,
and supports many of that command's features, such as multi-period reports.
It is similar to `hledger balance -H assets liabilities`,
but with smarter account detection, and liabilities displayed with
their sign flipped.

This command also supports the
[output destination](hledger.html#output-destination) and
[output format](hledger.html#output-format) options
The output formats supported are
`txt`, `csv`, `tsv`, `html`, and (experimental) `json`.
