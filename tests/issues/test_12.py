# Under the following conditions, the return type doesn't get included in the 
# fold:
# - Return on a new line with the parenthesis (such as black formats)
# - Whitespace in the type annotation (after comma)

def get_admission_tables(
    profiles: List[str]
) -> Tuple[pd.DataFrame, pd.DataFrame]:
    spam = 1
    eggs = 2

def get_admission_tables(
    profiles: List[str]
) -> Tuple[pd.DataFrame,pd.DataFrame]:
    spam = 1
    eggs = 2


