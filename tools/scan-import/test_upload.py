"""Tests for the SQL builder in upload.py (no network, no database). Run: python3 -m unittest"""

from __future__ import annotations

import json
import unittest

from upload import ROW_COLUMNS, insert_sql


class InsertSqlTests(unittest.TestCase):
    def test_rows_travel_as_one_json_document(self):
        row = {c: None for c in ROW_COLUMNS} | {"report": "Patient's \"sign\"; drop table x;", "gate": {"answers": []}}
        sql = insert_sql([row])
        document = sql.split("$rows$")[1]
        self.assertEqual(json.loads(document)[0]["report"], row["report"])
        self.assertTrue(sql.startswith("insert into private.scan_assets ("))


if __name__ == "__main__":
    unittest.main()
