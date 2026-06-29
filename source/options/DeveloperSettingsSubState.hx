package options;

class DeveloperSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Developer Settings';
		rpcTitle = 'Developer Settings Menu';

		var option:Option = new Option('Developer Mode',
			'If checked, enables developer shortcuts:\nPress 7 to open the Editor Picker,\naccess Chart Editor and Character Editor from PlayState.',
			'developerMode',
			BOOL);
		addOption(option);

		super();
	}
}