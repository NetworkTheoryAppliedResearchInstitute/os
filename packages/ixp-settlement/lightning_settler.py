"""
NTARI OS — IXP Settlement: Lightning Invoice Generator
packages/ixp-settlement/lightning_settler.py

Calls SoHoLINK's payment API to generate and track Lightning invoices
for paid peering settlement.

SoHoLINK endpoints used (no modifications to SoHoLINK required):
  POST /api/revenue/request-payout  — request payout to IXP operator
  GET  /api/revenue/payouts         — audit trail

All HTTP calls use urllib (stdlib only — no requests dependency).
"""

import json
import urllib.error
import urllib.request
from datetime import datetime


class LightningSettler:

    def __init__(self, api_base, timeout=10):
        self._api = api_base.rstrip("/")
        self._timeout = timeout

    def _post(self, path, payload):
        body = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            f"{self._api}{path}",
            data=body,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "NTARI-OS-IXP-Settlement/0.1",
            },
            method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as exc:
            raise RuntimeError(
                f"SoHoLINK HTTP {exc.code} on POST {path}: "
                f"{exc.read().decode(errors='replace')[:200]}"
            ) from exc
        except Exception as exc:
            raise RuntimeError(f"SoHoLINK request failed: {exc}") from exc

    def _get(self, path):
        req = urllib.request.Request(
            f"{self._api}{path}",
            headers={"User-Agent": "NTARI-OS-IXP-Settlement/0.1"}
        )
        try:
            with urllib.request.urlopen(req, timeout=self._timeout) as resp:
                return json.loads(resp.read())
        except Exception as exc:
            raise RuntimeError(f"SoHoLINK GET {path} failed: {exc}") from exc

    def request_payout(self, asn, amount_sats, description="IXP peering settlement"):
        """
        Request a Lightning payout from SoHoLINK on behalf of the IXP.
        Returns the invoice ID / payment hash from SoHoLINK response.
        """
        payload = {
            "amount_sats": amount_sats,
            "description": description,
            "metadata": {
                "asn": asn,
                "service": "ixp_peering",
                "timestamp": datetime.utcnow().isoformat(),
            },
        }
        resp = self._post("/api/revenue/request-payout", payload)
        return resp.get("invoice_id") or resp.get("payment_hash")

    def topup_member(self, asn, amount_sats):
        """Top up a pre-funded member wallet."""
        payload = {"asn": asn, "amount_sats": amount_sats}
        return self._post("/api/wallet/topup", payload)

    def list_payouts(self, limit=50):
        """Fetch audit trail of recent payouts."""
        return self._get(f"/api/revenue/payouts?limit={limit}")

    def health_check(self):
        """Return True if SoHoLINK API is reachable."""
        try:
            self._get("/api/health")
            return True
        except Exception:
            return False
