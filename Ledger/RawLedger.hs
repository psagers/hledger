{-|

A 'RawLedger' is a parsed ledger file. We call it raw to distinguish from
the cached 'Ledger'.

-}

module Ledger.RawLedger
where
import qualified Data.Map as Map
import Ledger.Utils
import Ledger.Types
import Ledger.AccountName
import Ledger.Amount
import Ledger.Entry
import Ledger.Transaction


negativepatternchar = '-'

instance Show RawLedger where
    show l = printf "RawLedger with %d entries, %d accounts: %s"
             ((length $ entries l) +
              (length $ modifier_entries l) +
              (length $ periodic_entries l))
             (length accounts)
             (show accounts)
             -- ++ (show $ rawLedgerTransactions l)
             where accounts = flatten $ rawLedgerAccountNameTree l

rawLedgerTransactions :: RawLedger -> [Transaction]
rawLedgerTransactions = txnsof . entries
    where txnsof es = concat $ map flattenEntry $ zip es [1..]

rawLedgerAccountNamesUsed :: RawLedger -> [AccountName]
rawLedgerAccountNamesUsed = accountNamesFromTransactions . rawLedgerTransactions

rawLedgerAccountNames :: RawLedger -> [AccountName]
rawLedgerAccountNames = sort . expandAccountNames . rawLedgerAccountNamesUsed

rawLedgerAccountNameTree :: RawLedger -> Tree AccountName
rawLedgerAccountNameTree l = accountNameTreeFrom $ rawLedgerAccountNames l

-- | Remove ledger entries we are not interested in.
-- Keep only those which fall between the begin and end dates, and match
-- the description pattern, and match the cleared flag.
filterRawLedger :: String -> String -> [String] -> Bool -> RawLedger -> RawLedger
filterRawLedger begin end pats clearedonly = 
    filterRawLedgerEntriesByClearedStatus clearedonly .
    filterRawLedgerEntriesByDate begin end .
    filterRawLedgerEntriesByDescription pats

-- | Keep only entries whose description matches the description pattern.
filterRawLedgerEntriesByDescription :: [String] -> RawLedger -> RawLedger
filterRawLedgerEntriesByDescription pats (RawLedger ms ps es f) = 
    RawLedger ms ps (filter matchdesc es) f
    where matchdesc = matchLedgerPatterns False pats . edescription

-- | Keep only entries which fall between begin and end dates. 
-- We include entries on the begin date and exclude entries on the end
-- date, like ledger.  An empty date string means no restriction.
filterRawLedgerEntriesByDate :: String -> String -> RawLedger -> RawLedger
filterRawLedgerEntriesByDate begin end (RawLedger ms ps es f) = 
    RawLedger ms ps (filter matchdate es) f
    where 
      d1 = parsedate begin :: UTCTime
      d2 = parsedate end
      matchdate e = (null begin || d >= d1) && (null end || d < d2)
                    where d = parsedate $ edate e

-- | Keep only entries with cleared status, if the flag is true, otherwise
-- do no filtering.
filterRawLedgerEntriesByClearedStatus :: Bool -> RawLedger -> RawLedger
filterRawLedgerEntriesByClearedStatus False l = l
filterRawLedgerEntriesByClearedStatus True  (RawLedger ms ps es f) =
    RawLedger ms ps (filter estatus es) f

-- | Check if a set of ledger account/description patterns matches the
-- given account name or entry description, applying ledger's special
-- cases.  
-- 
-- Patterns are case-insensitive regular expression strings, and those
-- beginning with - are negative patterns.  The special case is that
-- account patterns match the full account name except in balance reports
-- when the pattern does not contain : and is a positive pattern, where it
-- matches only the leaf name.
matchLedgerPatterns :: Bool -> [String] -> String -> Bool
matchLedgerPatterns forbalancereport pats str =
    (null positives || any ismatch positives) && (null negatives || not (any ismatch negatives))
    where 
      isnegative = (== negativepatternchar) . head
      (negatives,positives) = partition isnegative pats
      ismatch pat = containsRegex (mkRegexWithOpts pat' True True) matchee
          where 
            pat' = if isnegative pat then drop 1 pat else pat
            matchee = if forbalancereport && not (':' `elem` pat) && not (isnegative pat)
                      then accountLeafName str
                      else str

-- | Give amounts the display settings of the first one detected in each commodity.
normaliseRawLedgerAmounts :: RawLedger -> RawLedger
normaliseRawLedgerAmounts l@(RawLedger ms ps es f) = RawLedger ms ps es' f
    where 
      es' = map normaliseEntryAmounts es
      normaliseEntryAmounts (Entry d s c desc comm ts pre) = Entry d s c desc comm ts' pre
          where ts' = map normaliseRawTransactionAmounts ts
      normaliseRawTransactionAmounts (RawTransaction acct a c t) = RawTransaction acct a' c t
          where a' = normaliseMixedAmount a
      firstcommodities = nubBy samesymbol $ allcommodities
      allcommodities = map commodity $ concat $ map (amounts . amount) $ rawLedgerTransactions l
      samesymbol (Commodity {symbol=s1}) (Commodity {symbol=s2}) = s1==s2
      firstoccurrenceof c@(Commodity {symbol=s}) = 
          fromMaybe
          (error "failed to normalise commodity") -- shouldn't happen
          (find (\(Commodity {symbol=sym}) -> sym==s) firstcommodities)
