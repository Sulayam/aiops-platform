import joblib, pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

URL = "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/main/inst/extdata/penguins.csv"
df = pd.read_csv(URL)

cols = ["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g","sex","island","species"]
df = df.dropna(subset=cols)
X = df[["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g","sex","island"]]
y = df["species"]

num = ["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g"]
cat = ["sex","island"]

pre = ColumnTransformer([
    ("num", StandardScaler(), num),
    ("cat", OneHotEncoder(handle_unknown="ignore"), cat)
])

clf = LogisticRegression(max_iter=500)
pipe = Pipeline([("pre", pre), ("clf", clf)])

Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)
pipe.fit(Xtr, ytr)
pred = pipe.predict(Xte)
print("accuracy:", round(accuracy_score(yte, pred), 3))

# persist into app/ so the API image can COPY it
joblib.dump(pipe, "app/model.pkl")
