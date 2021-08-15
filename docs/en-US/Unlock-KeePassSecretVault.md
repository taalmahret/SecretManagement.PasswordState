---
external help file: SecretManagement.PasswordState.Extension.psm1-help.xml
Module Name: SecretManagement.PasswordState
online version:
schema: 2.0.0
---

# Unlock-KeePassSecretVault

## SYNOPSIS
Enables the entry of a master password prior to vault activities for unattended scenarios. 
If registering a vault for the first time unattended, be sure to use the -SkipValidate parameter of Register-KeepassSecretVault

## SYNTAX

```
Unlock-KeePassSecretVault [-Password] <SecureString> [-Name] <String> [<CommonParameters>]
```

## DESCRIPTION
{{ Fill in the Description }}

## EXAMPLES

### EXAMPLE 1
```
Get-SecretVault 'MyKeepassVault' | Unlock-KeePassSecretVault -Password $MySecureString
```

### EXAMPLE 2
```
Unlock-KeePassSecretVault -Name 'MyKeepassVault' -Password $MySecureString
```

## PARAMETERS

### -Password
{{ Fill Password Description }}

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Name
{{ Fill Name Description }}

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
