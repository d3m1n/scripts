## HOW TO USE
```bash
curl -s "https://raw.githubusercontent.com/d3m1n/scripts/main/dotnet-blacklist/install.sh" | bash
```

## WHAT IT DOES
Creates or updates `/etc/apt/apt.conf.d/99-dotnet-blacklist` to prevent `dotnet*` and `aspnetcore*` packages from being automatically upgraded by unattended-upgrades.

### Blacklist contents
```
Unattended-Upgrade::Package-Blacklist {
  "dotnet*";
  "aspnetcore*";
};
```

The script is idempotent – running it multiple times produces the same result without duplicating entries. It validates the configuration syntax after writing and reports a clear status message.