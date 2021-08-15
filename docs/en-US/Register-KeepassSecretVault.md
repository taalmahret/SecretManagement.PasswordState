---
external help file: SecretManagement.PasswordState.Extension.psm1-help.xml
Module Name: SecretManagement.PasswordState
online version:
schema: 2.0.0
---

# Register-KeepassSecretVault

## SYNOPSIS
Registers a Keepass Vault with the Secret Management engine

## SYNTAX

### UseMasterPassword (Default)
```
Register-KeepassSecretVault -Path <String> [-Name <String>] [-KeyPath <String>] [-UseMasterPassword]
 [-UseWindowsAccount] [-ShowFullTitle] [-ShowRecycleBin] [<CommonParameters>]
```

### Create
```
Register-KeepassSecretVault -Path <String> [-Name <String>] [-KeyPath <String>] [-UseMasterPassword]
 [-UseWindowsAccount] [-Create] [-MasterPassword <SecureString>] [-ShowFullTitle] [-ShowRecycleBin]
 [<CommonParameters>]
```

### SkipValidate
```
Register-KeepassSecretVault -Path <String> [-Name <String>] [-KeyPath <String>] [-UseMasterPassword]
 [-UseWindowsAccount] [-ShowFullTitle] [-ShowRecycleBin] [-SkipValidate] [<CommonParameters>]
```

## DESCRIPTION
Enables you to register a keepass vault with the secret management engine, with more discoverable parameters and
safety checks

## EXAMPLES

### EXAMPLE 1
```
Register-KeepassSecretVault -Path $HOME/Desktop/MyVault.kdbx
Explanation of what the example does
```

## PARAMETERS

### -Path
Path to your kdbx database file

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Name
Name of your secret management vault.
Defaults to the base filename

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeyPath
Path to your kdbx keyfile path if you use one.
Only v1 keyfiles (2.44 and older) are currently supported

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseMasterPassword
Prompt for a master password for the vault

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseWindowsAccount
Use your Windows Login account as an authentication factor for the vault

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Create
Automatically create a keepass database with the specifications you provided

```yaml
Type: SwitchParameter
Parameter Sets: Create
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -MasterPassword
Specify the master password to use when automatically creating a vault

```yaml
Type: SecureString
Parameter Sets: Create
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowFullTitle
Report key titles as full paths including folders.
Useful if you want to view conflicting Keys

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowRecycleBin
Show Recycle Bin entries

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipValidate
Don't validate the vault operation upon registration.
This is useful for pre-staging 
vaults or vault configurations in deployments.

```yaml
Type: SwitchParameter
Parameter Sets: SkipValidate
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
