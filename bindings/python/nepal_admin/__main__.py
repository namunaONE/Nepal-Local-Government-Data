"""Print a summary: ``python -m nepal_admin``."""

from . import (
    DATA_AS_OF,
    get_national_stats,
    get_province_stats,
    get_province_by_id,
    get_local_body_by_cbs,
)


def main():
    s = get_national_stats()
    print("Nepal administrative divisions (data as of {})".format(DATA_AS_OF))
    print("  provinces          {}".format(s["provinces"]))
    print("  districts          {}".format(s["districts"]))
    print("  local bodies       {}".format(s["total"]))
    print("  wards (declared)   {}".format(s["wards"]))
    print("  wards (verified)   {}".format(s["verified_wards"]))
    b = get_local_body_by_cbs(31304)
    if b:
        print("\n  31304 = {} ({})".format(b["name"], b["nameNe"]))
    bagmati = get_province_by_id("bagmati")
    if bagmati:
        ps = get_province_stats("bagmati")
        print("  Bagmati: {} districts, {} wards ({} unreconciled)".format(
            bagmati["districtCount"], ps["verified_wards"], ps["unreconciled_wards"]
        ))


if __name__ == "__main__":
    main()
