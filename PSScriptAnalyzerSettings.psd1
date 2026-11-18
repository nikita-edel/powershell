# Analyzer rules for PowerShell Editor Services in this repo.
# Same as the editor default set, minus:
#   - UnresolvedCommand (custom nvim rule): functions and aliases come from other dot-sourced files and modules
#   - PSAvoidUsingCmdletAliases: aliases are used on purpose in a shell profile
@{
	IncludeRules = @(
		'PSAvoidAssignmentToAutomaticVariable'
		'PSUseToExportFieldsInManifest'
		'PSMisleadingBacktick'
		'PSUseApprovedVerbs'
		'PSAvoidUsingPlainTextForPassword'
		'PSReservedCmdletChar'
		'PSReservedParams'
		'PSShouldProcess'
		'PSMissingModuleManifestField'
		'PSAvoidDefaultValueSwitchParameter'
		'PSUseDeclaredVarsMoreThanAssignments'
		'PSPossibleIncorrectComparisonWithNull'
		'PSAvoidDefaultValueForMandatoryParameter'
		'PSPossibleIncorrectUsageOfRedirectionOperator'
	)
}
