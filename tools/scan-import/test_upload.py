"""Tests for the SQL builder in upload.py (no network, no database). Run: python3 -m unittest"""

from __future__ import annotations

import json
import unittest

from upload import ROW_COLUMNS, curl_config, insert_sql


class InsertSqlTests(unittest.TestCase):
    def test_rows_travel_as_one_json_document(self):
        row = {c: None for c in ROW_COLUMNS} | {"report": "Patient's \"sign\"; drop table x;", "gate": {"answers": []}}
        sql = insert_sql([row])
        document = sql.split("$rows$")[1]
        self.assertEqual(json.loads(document)[0]["report"], row["report"])
        self.assertTrue(sql.startswith("insert into private.scan_assets ("))

    def test_rerun_skips_rows_already_inserted(self):
        sql = insert_sql([{c: None for c in ROW_COLUMNS}])
        self.assertTrue(sql.rstrip().endswith("on conflict (object_name) do nothing;"))


class CurlConfigTests(unittest.TestCase):
    def test_upload_overwrites_an_existing_object(self):
        config = curl_config("KEY").splitlines()
        self.assertIn('header = "x-upsert: true"', config)
        self.assertIn('header = "Authorization: Bearer KEY"', config)
        self.assertIn('header = "apikey: KEY"', config)


if __name__ == "__main__":
    unittest.main()
