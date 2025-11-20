using Dates

timezone = round(now() - now(UTC), Minute(30))
timezone_sign = sign(timezone)
timezone = round(now(), Day(1)) + timezone_sign * timezone

backup_time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS") * " UTC" * (timezone_sign ≥ 0 ? "+" : "-") * Dates.format(timezone, "HHMM")

run(`git commit -m "backup: $backup_time"`)
