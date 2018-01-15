#include <a_samp>

main()
{
	SetGameModeText("Test V0.1.");
}

#include <a_mysql>
#include <zcmd>
#include <sscanf2>
#include <easydialog>
#include <kickban>

#define COLOR_WHITE (0xFFFFFFFF)
#define COL_WHITE "{FFFFFF}"

#define COLOR_TOMATO (0xFF6347FF)
#define COL_TOMATO "{FF6347}"

#define COLOR_YELLOW (0xFFDD00FF)
#define COL_YELLOW "{FFDD00}"

#define COLOR_GREEN (0x00FF00FF)
#define COL_GREEN "{00FF00}"

#define COLOR_DEFAULT (0xA9C4E4FF)
#define COL_DEFAULT "{A9C4E4}"

#define MAX_LOGIN_ATTEMPTS 3
#define MAX_ACCOUNT_LOCKTIME 30 // mins

#define MIN_PASSWORD_LENGTH 4
#define MAX_PASSWORD_LENGTH 45

//#define SECURE_PASSWORD_ONLY // 这会强制用户在其密码中至少有1个小写字母，1个大写字母和1个数字

#define MAX_SECURITY_QUESTION_SIZE 256

new MySQL:conn;

new const SECURITY_QUESTIONS[][MAX_SECURITY_QUESTION_SIZE] =
{
	"1",
	"2"
	/*"你的小名是?",
	"你的童年朋友名字是?",
	"你的家乡是哪里?",
	"你孩子的小名叫?",
	"你最喜欢哪个足球队伍?",
	"你最喜欢的电影是?",
	"你初吻的男孩或女孩名字是?",
	"你的第一辆车的品牌和型号是?",
	"你出生的医院叫?",
	"谁是你的童年所认可的英雄?",
	"你的第一份工作是在?",
	"你的第一份工作是?",
	"你小学是哪个学校?",
	"你小学最喜欢的老师叫?"*/
};

enum e_USER
{
	e_USER_SQLID,
	e_USER_PASSWORD[129],
	e_USER_SALT[64 + 1],
	e_USER_KILLS,
	e_USER_DEATHS,
	e_USER_SCORE,
	e_USER_MONEY,
	e_USER_ADMIN_LEVEL,
	e_USER_VIP_LEVEL,
	e_USER_REGISTER_TIMESTAMP,
	e_USER_LASTLOGIN_TIMESTAMP,
	e_USER_SECURITY_QUESTION[MAX_SECURITY_QUESTION_SIZE],
	e_USER_SECURITY_ANSWER[64 + 1]
};
new eUser[MAX_PLAYERS][e_USER];
new iLoginAttempts[MAX_PLAYERS];
new iAnswerAttempts[MAX_PLAYERS];

IpToLong(const address[])
{
	new parts[4];
	sscanf(address, "p<.>a<i>[4]", parts);
	return ((parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]);
}

ReturnTimelapse(start, till)
{
    new ret[32];
	new seconds = till - start;

	const
		MINUTE = 60,
		HOUR = 60 * MINUTE,
		DAY = 24 * HOUR,
		MONTH = 30 * DAY;

	if (seconds == 1)
		format(ret, sizeof(ret), "一秒");
	if (seconds < (1 * MINUTE))
		format(ret, sizeof(ret), "%i 秒", seconds);
	else if (seconds < (2 * MINUTE))
		format(ret, sizeof(ret), "一分钟");
	else if (seconds < (45 * MINUTE))
		format(ret, sizeof(ret), "%i 分钟", (seconds / MINUTE));
	else if (seconds < (90 * MINUTE))
		format(ret, sizeof(ret), "一小时");
	else if (seconds < (24 * HOUR))
		format(ret, sizeof(ret), "%i 小时", (seconds / HOUR));
	else if (seconds < (48 * HOUR))
		format(ret, sizeof(ret), "一天");
	else if (seconds < (30 * DAY))
		format(ret, sizeof(ret), "%i 天", (seconds / DAY));
	else if (seconds < (12 * MONTH))
    {
		new months = floatround(seconds / DAY / 30);
      	if (months <= 1)
			format(ret, sizeof(ret), "一月");
      	else
			format(ret, sizeof(ret), "%i 月", months);
	}
    else
    {
      	new years = floatround(seconds / DAY / 365);
      	if (years <= 1)
			format(ret, sizeof(ret), "一年");
      	else
			format(ret, sizeof(ret), "%i 年", years);
	}
	return ret;
}

public OnGameModeInit()
{
    new MySQLOpt:options = mysql_init_options();
    mysql_set_option(options, SERVER_PORT, 3306);

    mysql_log(ALL);

    conn = mysql_connect("localhost", "root", "root", "sa-mp", options);
    mysql_tquery(conn,"SET NAMES utf8");
	mysql_tquery(conn,"set character_set_client=\'utf8\'");
	mysql_tquery(conn,"set character_set_results=\'utf8\'");
	mysql_tquery(conn,"set collation_connection=\'utf8_general_ci\'");
	mysql_set_charset("utf8");
	new string[1024];
	string = "CREATE TABLE IF NOT EXISTS `users`(\
		`id` INT, \
		`name` VARCHAR(24), \
		`ip` VARCHAR(18), \
		`longip` INT, \
		`password` VARCHAR(64), \
		`salt` VARCHAR(64), \
		`sec_question` VARCHAR("#MAX_SECURITY_QUESTION_SIZE"), \
		`sec_answer` VARCHAR(64), ";
	strcat(string, "`register_timestamp` INT, \
		`lastlogin_timestamp` INT, \
		`kills` INT, \
		`deaths` INT, \
		`score` INT, \
		`money` INT, \
		`adminlevel` INT, \
		`viplevel` INT, \
		PRIMARY KEY(`id`))");
	mysql_tquery(conn, string);

	mysql_tquery(conn, "CREATE TABLE IF NOT EXISTS `temp_blocked_users` (\
		`ip` VARCHAR(18), \
		`lock_timestamp` INT, \
		`user_id` INT)");

    EnableVehicleFriendlyFire();
    DisableInteriorEnterExits();
	UsePlayerPedAnims();
	return 1;
}

public OnGameModeExit()
{
	mysql_close(conn);
	return 1;
}

public OnPlayerConnect(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);

	new string[150];
	mysql_format(conn, string, sizeof(string), "SELECT * FROM `users` WHERE `name` = '%e' LIMIT 1", name);
	mysql_tquery(conn, string, "OnPlayerJoin", "i", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	if(GetPVarInt(playerid, "LoggedIn") == 1)
	{
		new string[1024],
		name[MAX_PLAYER_NAME];

		GetPlayerName(playerid, name, MAX_PLAYER_NAME);

		mysql_format(conn, string, sizeof(string), "UPDATE `users` SET `name` = '%s', `password` = '%s', `salt` = '%s', `sec_question` = '%s', `sec_answer` = '%s', `kills` = %d, `deaths` = %d, `score` = %d, `money` = %d, `adminlevel` = %d, `viplevel` = %d WHERE `id` = %d",
		name, eUser[playerid][e_USER_PASSWORD], eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_SECURITY_QUESTION], eUser[playerid][e_USER_SECURITY_ANSWER],  eUser[playerid][e_USER_KILLS], eUser[playerid][e_USER_DEATHS], GetPlayerScore(playerid), GetPlayerMoney(playerid), eUser[playerid][e_USER_ADMIN_LEVEL], eUser[playerid][e_USER_VIP_LEVEL], eUser[playerid][e_USER_SQLID]);
		mysql_tquery(conn, string);
	}
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	if (!GetPVarInt(playerid, "LoggedIn"))
	{
	    SetPlayerCameraPos(playerid, -144.2838, 1244.2357, 35.6595);
		SetPlayerCameraLookAt(playerid, -144.2255, 1243.2335, 35.3393, CAMERA_MOVE);
	}
	else
	{
    	SetPlayerPos(playerid, -314.7314, 1052.8170, 20.3403);
     	SetPlayerFacingAngle(playerid, 357.8575);
     	SetPlayerCameraPos(playerid, -312.2127, 1055.5232, 20.5785);
		SetPlayerCameraLookAt(playerid, -313.0236, 1054.9427, 20.5334, CAMERA_MOVE);
	}
 	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if (!GetPVarInt(playerid, "LoggedIn"))
	{
	    GameTextForPlayer(playerid, "~n~~n~~n~~n~~r~Login/Register first before spawning!", 3000, 3);
	    return 0;
	}
	return 1;
}

public OnPlayerSpawn(playerid)
{
    SetPlayerPos(playerid, -314.7314, 1052.8170, 20.3403);
   	SetPlayerFacingAngle(playerid, 357.8575);
	return 1;
}

forward OnPlayerJoin(playerid);
public OnPlayerJoin(playerid)
{
	for (new i; i < 100; i++)
	{
	    SendClientMessage(playerid, COLOR_WHITE, "");
	}
	SendClientMessage(playerid, COLOR_YELLOW, "你正在连接 \"SA-MP 0.3.7 服务器\"");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);

	if (cache_num_rows() == 0)
	{
	    eUser[playerid][e_USER_SQLID] = -1;
	    eUser[playerid][e_USER_PASSWORD][0] = EOS;
	    eUser[playerid][e_USER_SALT][0] = EOS;
		eUser[playerid][e_USER_KILLS] = 0;
		eUser[playerid][e_USER_DEATHS] = 0;
		eUser[playerid][e_USER_SCORE] = 0;
		eUser[playerid][e_USER_MONEY] = 0;
		eUser[playerid][e_USER_ADMIN_LEVEL] = 0;
		eUser[playerid][e_USER_VIP_LEVEL] = 0;
		eUser[playerid][e_USER_REGISTER_TIMESTAMP] = 0;
		eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP] = 0;
		eUser[playerid][e_USER_SECURITY_QUESTION][0] = EOS;
		eUser[playerid][e_USER_SECURITY_ANSWER][0] = EOS;

		Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "账户注册... [步骤: 1/3]", COL_WHITE "欢迎来到我们的服务器. 我们会给你 "COL_GREEN"3 个简单的步骤 "COL_WHITE"来注册你的账户!\n请输入你的密码, "COL_TOMATO"然后点击"COL_WHITE" 确定.", "确定", "选项");
		SendClientMessage(playerid, COLOR_WHITE, "[步骤: 1/3] 输入你的新账户密码.");
	}
	else
	{
		iLoginAttempts[playerid] = 0;
		iAnswerAttempts[playerid] = 0;

		cache_get_value_name_int(0, "id", eUser[playerid][e_USER_SQLID]);
		cache_get_value_name(0, "password", eUser[playerid][e_USER_PASSWORD], 129);
		cache_get_value_name(0, "salt", eUser[playerid][e_USER_SALT], 64);
		eUser[playerid][e_USER_SALT][64] = EOS;
		cache_get_value_name_int(0, "kills", eUser[playerid][e_USER_KILLS]);
		cache_get_value_name_int(0, "deaths", eUser[playerid][e_USER_DEATHS]);
		cache_get_value_name_int(0, "score", eUser[playerid][e_USER_SCORE]);
		cache_get_value_name_int(0, "money", eUser[playerid][e_USER_MONEY]);
		cache_get_value_name_int(0, "adminlevel", eUser[playerid][e_USER_ADMIN_LEVEL]);
		cache_get_value_name_int(0, "viplevel", eUser[playerid][e_USER_VIP_LEVEL]);
		cache_get_value_name_int(0, "register_timestamp", eUser[playerid][e_USER_REGISTER_TIMESTAMP]);
		cache_get_value_name_int(0, "lastlogin_timestamp", eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP]);
		cache_get_value_name(0, "sec_question", eUser[playerid][e_USER_SECURITY_QUESTION], MAX_SECURITY_QUESTION_SIZE);
		cache_get_value_name(0, "sec_answer", eUser[playerid][e_USER_SECURITY_ANSWER], MAX_PASSWORD_LENGTH * 2);
		cache_unset_active();
		
		if(!strcmp(GetName(playerid), "Alex_Sam", true))
		{
			if(eUser[playerid][e_USER_ADMIN_LEVEL] != 5)
			{
                eUser[playerid][e_USER_ADMIN_LEVEL] = 5;
			}
		}

		new string[512];
		mysql_format(conn, string, sizeof(string), "SELECT `lock_timestamp` FROM `temp_blocked_users` WHERE `user_id` = %i LIMIT 1", eUser[playerid][e_USER_SQLID]);
		new Cache:lock_result = mysql_query(conn, string);
		if (cache_num_rows() == 1)
		{
			new lock_timestamp;
			cache_get_value_index_int(0, 0, lock_timestamp);
			if ((gettime() - lock_timestamp) < 0)
		    {
		        SendClientMessage(playerid, COLOR_TOMATO, "抱歉! 你的账户将被锁定. 错误密码 "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS".");
		        format(string, sizeof(string), "剩余尝试数量 %s.", ReturnTimelapse(gettime(), lock_timestamp));
				SendClientMessage(playerid, COLOR_TOMATO, string);
				cache_delete(lock_result);
				return Kick(playerid);
		    }
		    else
		    {
		        new ip[18];
				GetPlayerIp(playerid, ip, 18);
		        mysql_format(conn, string, sizeof(string), "DELETE FROM `temp_blocked_users` WHERE `user_id` = %i AND `ip` = '%s'", eUser[playerid][e_USER_SQLID], ip);
		        mysql_tquery(conn, string);
		    }
		}
		cache_delete(lock_result);

		Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "账户登录...", COL_WHITE "输入你的密码访问该账户. 如果你尝试 "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"次, 账户将被锁定 "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"分钟.", "确定", "选项");
	}
	return 1;
}

Dialog:LOGIN(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
	    return 1;
	}

	new string[512];

	new hash[256];
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], hash, sizeof(hash));
	if (strcmp(hash, eUser[playerid][e_USER_PASSWORD]))
	{
		if (++iLoginAttempts[playerid] == MAX_LOGIN_ATTEMPTS)
		{
		    new lock_timestamp = gettime() + (MAX_ACCOUNT_LOCKTIME * 60);
		    new ip[18];
		    GetPlayerIp(playerid, ip, 18);
			mysql_format(conn, string, sizeof(string), "INSERT INTO `temp_blocked_users` VALUES('%s', %i, %i)", ip, lock_timestamp, eUser[playerid][e_USER_SQLID]);
			mysql_tquery(conn, string);

		    SendClientMessage(playerid, COLOR_TOMATO, "抱歉! 你的账户将被锁定. 错误密码 "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS".");
		    format(string, sizeof(string), "如果您忘记了密码/用户名，请在下次登录窗口中点击“选项” (账户已被冻结 %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    Dialog_Show(playerid, LOGIN, DIALOG_STYLE_INPUT, "账户登陆...", COL_WHITE "输入你的密码访问该账户. 如果你尝试错误密码 "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"次,账户将被锁定 "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"分钟.", "确定", "选项");
	    format(string, sizeof(string), "错误密码! 你尝试登录: %i/"#MAX_LOGIN_ATTEMPTS" 次.", iLoginAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	new name[MAX_PLAYER_NAME],
		ip[18];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);
	GetPlayerIp(playerid, ip, 18);
	mysql_format(conn, string, sizeof(string), "UPDATE `users` SET `lastlogin_timestamp` = %i, `ip` = '%s', `longip` = %i WHERE `id` = %i", gettime(), ip, IpToLong(ip), eUser[playerid][e_USER_SQLID]);
	mysql_tquery(conn, string);

	format(string, sizeof(string), "成功登录! 欢迎回到 %s, 我们享受这里的一切. [最后登录: %s 前]", name, ReturnTimelapse(eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	SetPVarInt(playerid, "LoggedIn", 1);
	OnPlayerRequestClass(playerid, 0);
	SpawnPlayer(playerid);
	return 1;
}

Dialog:REGISTER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
	    return 1;
	}

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "账户注册... [步骤: 1/3]", COL_WHITE "欢迎回来. 我们将提供 "COL_GREEN"3 个简单步骤 "COL_WHITE"来注册你的账户,如果你忘记了密码请点击下方选项菜单!\n请输入你要注册的密码, "COL_TOMATO"区分大小写"COL_WHITE".", "确定", "选项");
		SendClientMessage(playerid, COLOR_TOMATO, "密码长度无效，长度要求 "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" 字符.");
	    return 1;
	}

	#if defined SECURE_PASSWORD_ONLY
		new bool:contain_number,
		    bool:contain_highercase,
		    bool:contain_lowercase;
		for (new i, j = strlen(inputtext); i < j; i++)
		{
		    switch (inputtext[i])
		    {
		        case '0'..'9':
		            contain_number = true;
				case 'A'..'Z':
				    contain_highercase = true;
				case 'a'..'z':
				    contain_lowercase = true;
		    }

		    if (contain_number && contain_highercase && contain_lowercase)
		        break;
		}

		if (!contain_number || !contain_highercase || !contain_lowercase)
		{
		    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_INPUT, "账户注册... [步骤: 1/3]", COL_WHITE "欢迎回来. 我们会提供 "COL_GREEN"3 个简单步骤 "COL_WHITE"来注册账户,如果你忘记了你的密码请点击下方选项菜单!\n请输入你要注册的密码进行注册, "COL_TOMATO"区分大小写"COL_WHITE".", "确定", "选项");
			SendClientMessage(playerid, COLOR_TOMATO, "密码字符必须包含一个字母和数字.");
		    return 1;
		}
	#endif

	for (new i; i < 64; i++)
	{
		eUser[playerid][e_USER_SALT][i] = (random('z' - 'A') + 'A');
	}
	eUser[playerid][e_USER_SALT][64] = EOS;
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_PASSWORD], 129);

	new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
	for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
	{
	    strcat(list, SECURITY_QUESTIONS[i]);
	    strcat(list, "\n");
	}
	Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "账户注册... [步骤: 2/3]", list, "确定", "返回");
	SendClientMessage(playerid, COLOR_WHITE, "[步骤: 2/3] 请选择一个安全问题. 这将保障你的账户安全,防止账户被盗以及忘记密码!");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:SEC_QUESTION(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_INPUT, "账户注册... [步骤: 1/3]", COL_WHITE "欢迎回来. 我们会提供 "COL_GREEN"3 个简单步骤 "COL_WHITE"来注册账户,如果你忘记了你的密码请点击下方选项菜单!\n请输入你要注册的密码进行注册, "COL_TOMATO"区分大小写"COL_WHITE".", "确定", "选项");
		SendClientMessage(playerid, COLOR_WHITE, "[步骤: 1/3] 输入您的新帐户的密码.");
		return 1;
	}

	format(eUser[playerid][e_USER_SECURITY_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[listitem]);

	new string[256];
	format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"在下方框内填写你的安全问题答案. (无大小写区分).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "账户注册... [步骤: 3/3]", string, "确定", "返回");
	SendClientMessage(playerid, COLOR_WHITE, "[步骤: 3/3] 写下你的安全问题的答案，你就完成了 :)");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:SEC_ANSWER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
		for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
		{
		    strcat(list, SECURITY_QUESTIONS[i]);
		    strcat(list, "\n");
		}
		Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "账户注册... [步骤: 2/3]", list, "确定", "返回");
		SendClientMessage(playerid, COLOR_WHITE, "[步骤: 2/3] 请选择一个安全问题. 这将保障你的账户安全,防止账户被盗以及忘记密码!");
		return 1;
	}

	new string[1024];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"在下方框内填写你的安全问题答案. (无大小写区分).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "账户注册... [步骤: 3/3]", string, "确定", "返回");
		SendClientMessage(playerid, COLOR_TOMATO, "安全答案不能少于 "#MIN_PASSWORD_LENGTH" 字符.");
		return 1;
	}

	for (new i, j = strlen(inputtext); i < j; i++)
	{
        inputtext[i] = tolower(inputtext[i]);
	}
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_SECURITY_ANSWER], 64);

	new name[MAX_PLAYER_NAME],
		ip[18];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);
	GetPlayerIp(playerid, ip, 18);
	mysql_format(conn, string, sizeof(string), "INSERT INTO `users`(`name`, `ip`, `longip`, `password`, `salt`, `sec_question`, `sec_answer`, `register_timestamp`, `lastlogin_timestamp`) VALUES('%s', '%s', '%d', '%s', '%s', '%s', '%s', '%d', '%d')", name, ip, IpToLong(ip), eUser[playerid][e_USER_PASSWORD], eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_SECURITY_QUESTION], eUser[playerid][e_USER_SECURITY_ANSWER], gettime(), gettime());
	mysql_tquery(conn, string, "OnPlayerRegister", "d", playerid);

	format(string, sizeof(string), "成功注册! 欢迎来到 %s, 我们享受这里的一切. [IP: %s]", name, ip);
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	SetPVarInt(playerid, "LoggedIn", 1);
	OnPlayerRequestClass(playerid, 0);
	SpawnPlayer(playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
    eUser[playerid][e_USER_SQLID] = cache_insert_id();
    cache_unset_active();
}

Dialog:OPTIONS(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		if (eUser[playerid][e_USER_SQLID] != -1)
			Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "帐户登录...", COL_WHITE "输入你的密码访问账户. 如果你尝试次数达到 "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"账户将被锁定 "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"分钟.", "确定", "选项");
		else
			Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "账户注册... [步骤: 1/3]", COL_WHITE "欢迎来到服务器,我们会提供 "COL_GREEN"3 个简单步骤 "COL_WHITE"注册你的账户!\n请输入你要注册的密码, "COL_TOMATO"区分大小写"COL_WHITE".", "确定", "选项");
		return 1;
	}

	switch (listitem)
	{
	    case 0:
	    {
	        if (eUser[playerid][e_USER_SQLID] == -1)
	        {
	            SendClientMessage(playerid, COLOR_TOMATO, "该账户未注册,如果你坚持觉得是已有账户可以点击忘记用户名选项.");
	        	Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
	        	return 1;
	        }

			new string[64 + MAX_SECURITY_QUESTION_SIZE];
			format(string, sizeof(string), COL_WHITE "回答您的安全问题以重置密码.\n\n"COL_TOMATO"%s", eUser[playerid][e_USER_SECURITY_QUESTION]);
			Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "忘记密码:", string, "下一步", "取消");
	    }
	    case 1:
	    {
	        const MASK = (-1 << (32 - 36));
			new string[256],
				ip[18];
			GetPlayerIp(playerid, ip, 18);
			mysql_format(conn, string, sizeof(string), "SELECT `name`, `lastlogin_timestamp` FROM `users` WHERE ((`longip` & %i) = %i) LIMIT 1", MASK, (IpToLong(ip) & MASK));
			mysql_tquery(conn, string, "OnUsernamesLoad", "i", playerid);
		}

	    case 2:
	    {
	        return Kick(playerid);
	    }
	}
	return 1;
}

forward OnUsernamesLoad(playerid);
public OnUsernamesLoad(playerid)
{
	if (cache_num_rows() == 0)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "该账户未验证你的电脑,这可能是你的第一次登陆!");
		Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
		return;
	}

	new list[25 * (MAX_PLAYER_NAME + 32)],
		name[MAX_PLAYER_NAME],
		lastlogin_timestamp;

	for (new i, j = ((cache_num_rows() > 10) ? (10) : (cache_num_rows())); i < j; i++)
	{
		cache_get_value_index(i, 0, name, MAX_PLAYER_NAME);
		cache_get_value_index_int(i, 1, lastlogin_timestamp);
	    format(list, sizeof(list), "%s"COL_TOMATO"%s "COL_WHITE"|| 最后登录: %s 前\n", list, name, ReturnTimelapse(lastlogin_timestamp, gettime()));
	}
	cache_unset_active();

	Dialog_Show(playerid, FORGOT_USERNAME, DIALOG_STYLE_LIST, "你的用户名历史...", list, "Ok", "");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
}

Dialog:FORGOT_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
	    return 1;
	}

	new string[256],
		hash[64];
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], hash, sizeof(hash));
	if (strcmp(hash, eUser[playerid][e_USER_SECURITY_ANSWER]))
	{
		if (++iAnswerAttempts[playerid] == MAX_LOGIN_ATTEMPTS)
		{
		    new lock_timestamp = gettime() + (MAX_ACCOUNT_LOCKTIME * 60);
		    new ip[18];
		    GetPlayerIp(playerid, ip, 18);
            mysql_format(conn, string, sizeof(string), "INSERT INTO `temp_blocked_users` VALUES('%s', %i, %i)", ip, lock_timestamp, eUser[playerid][e_USER_SQLID]);
			mysql_tquery(conn, string);

		    SendClientMessage(playerid, COLOR_TOMATO, "抱歉! 该账户被禁止在你的电脑上登陆 "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS" 失败尝试.");
		    format(string, sizeof(string), "如果你忘记了你的密码/用户名,你可以在登录界面选择`选项`进行问题验证 (你尝试 %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    format(string, sizeof(string), COL_WHITE "回答您的安全问题以重置密码.\n\n"COL_TOMATO"%s", eUser[playerid][e_USER_SECURITY_QUESTION]);
		Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "忘记密码:", string, "下一步", "取消");
		format(string, sizeof(string), "错误答案: %i/"#MAX_LOGIN_ATTEMPTS" 尝试.", iAnswerAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "重置密码:", COL_WHITE "输入一个新的账户密码,如果你想修改你的账户安全问题,请使用/ucp.", "确定", "");
	SendClientMessage(playerid, COLOR_GREEN, "成功验证了您的安全问题！ 你现在可以重置你的密码.");
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:RESET_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "重置密码:", COL_WHITE "输入一个新的账户密码,如果你想修改你的账户安全问题,请使用/ucp.", "确定", "");
		return 1;
	}

	new string[256];

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "重置密码:", COL_WHITE "输入一个新的账户密码,如果你想修改你的账户安全问题,请使用/ucp.", "确定", "");
		SendClientMessage(playerid, COLOR_TOMATO, "密码只能存在 "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" 字符.");
	    return 1;
	}

	#if defined SECURE_PASSWORD_ONLY
		new bool:contain_number,
		    bool:contain_highercase,
		    bool:contain_lowercase;
		for (new i, j = strlen(inputtext); i < j; i++)
		{
		    switch (inputtext[i])
		    {
		        case '0'..'9':
		            contain_number = true;
				case 'A'..'Z':
				    contain_highercase = true;
				case 'a'..'z':
				    contain_lowercase = true;
		    }

		    if (contain_number && contain_highercase && contain_lowercase)
		        break;
		}

		if (!contain_number || !contain_highercase || !contain_lowercase)
		{
		    Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "R重置密码:", COL_WHITE "输入一个新的账户密码,如果你想修改你的账户安全问题,请使用/ucp.", "确定", "");
			SendClientMessage(playerid, COLOR_TOMATO, "密码字符不足, 必须包含字母和数字.");
		    return 1;
		}
	#endif

	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_PASSWORD], 129);

	new name[MAX_PLAYER_NAME],
		ip[18];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);
	GetPlayerIp(playerid, ip, 18);
	mysql_format(conn, string, sizeof(string), "UPDATE `users` SET `password` = '%e', `ip` = '%s', `longip` = %i, `lastlogin_timestamp` = %i WHERE `id` = %i", eUser[playerid][e_USER_PASSWORD], ip, IpToLong(ip), gettime(), eUser[playerid][e_USER_SQLID]);
	mysql_tquery(conn, string);

	format(string, sizeof(string), "成功使用新密码登录! 欢迎回到服务器 %s, 我们享受这里的一切. [最后登录时间: %s 前]", name, ReturnTimelapse(eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	SetPVarInt(playerid, "LoggedIn", 1);
	OnPlayerRequestClass(playerid, 0);
	return 1;
}

Dialog:FORGOT_USERNAME(playerid, response, listitem, inputtext[])
{
	Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "账户选项...", "忘记密码\n忘记用户名\n退出游戏", "选择", "返回");
	return 1;
}

CMD:changepass(playerid, params[])
{
	if (eUser[playerid][e_USER_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "只有注册用户能使用该指令.");
		return 1;
	}

    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "修改账户密码...", COL_WHITE "修改账户密码 "COL_YELLOW"区分大小写"COL_WHITE".", "确定", "取消");
	SendClientMessage(playerid, COLOR_WHITE, "输入新密码.");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
		return 1;

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "修改账户密码...", COL_WHITE "修改账户密码 "COL_YELLOW"区分大小写"COL_WHITE".", "确定", "取消");
		SendClientMessage(playerid, COLOR_TOMATO, "密码无效,必须 "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" 字符.");
	    return 1;
	}

	#if defined SECURE_PASSWORD_ONLY
		new bool:contain_number,
		    bool:contain_highercase,
		    bool:contain_lowercase;
		for (new i, j = strlen(inputtext); i < j; i++)
		{
		    switch (inputtext[i])
		    {
		        case '0'..'9':
		            contain_number = true;
				case 'A'..'Z':
				    contain_highercase = true;
				case 'a'..'z':
				    contain_lowercase = true;
		    }

		    if (contain_number && contain_highercase && contain_lowercase)
		        break;
		}

		if (!contain_number || !contain_highercase || !contain_lowercase)
		{
		    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_INPUT, "修改账户密码...", COL_WHITE "修改你的账户密码 "COL_YELLOW"区分大小写"COL_WHITE".", "确定", "取消");
			SendClientMessage(playerid, COLOR_TOMATO, "密码必须含有字母和数字.");
		    return 1;
		}
	#endif

	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_PASSWORD], 129);

	new string[256];
	for (new i, j = strlen(inputtext); i < j; i++)
	{
	    inputtext[i] = '*';
	}
	format(string, sizeof(string), "成功修改你的密码. [P: %s]", inputtext);
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

CMD:changeques(playerid, params[])
{
	if (eUser[playerid][e_USER_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "只有注册用户才能使用这个命令.");
		return 1;
	}

    new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
	for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
	{
	    strcat(list, SECURITY_QUESTIONS[i]);
	    strcat(list, "\n");
	}
	Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "修改账户安全问题... [步骤: 1/2]", list, "确定", "取消");
	SendClientMessage(playerid, COLOR_WHITE, "[步骤: 1/2] 请填写一个安全问题及回答,这有助于账户安全!");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_SEC_QUESTION(playerid, response, listitem, inputext[])
{
	if (!response)
		return 1;

	SetPVarInt(playerid, "Question", listitem);

	new string[256];
	format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"请在下方填写你的问题答案. (答案不分大小写).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "修改账户安全问题... [步骤: 2/2]", string, "确定", "返回");
	SendClientMessage(playerid, COLOR_WHITE, "[步骤: 2/2] 写下你的安全问题的答案.");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_SEC_ANSWER(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
		for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
		{
		    strcat(list, SECURITY_QUESTIONS[i]);
		    strcat(list, "\n");
		}
		Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "修改账户安全问题... [步骤: 1/2]", list, "确定", "取消");
		SendClientMessage(playerid, COLOR_WHITE, "[步骤: 1/2] 请填写一个安全问题及回答,这有助于账户安全!");
		return 1;
	}

	new string[512];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"请在下方填写你的问题答案. (答案不分大小写).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "修改账户安全问题... [步骤: 2/2]", string, "确定", "返回");
		SendClientMessage(playerid, COLOR_TOMATO, "答案不能少于 "#MIN_PASSWORD_LENGTH" 字符.");
		return 1;
	}

	format(eUser[playerid][e_USER_SECURITY_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[GetPVarInt(playerid, "Question")]);
	DeletePVar(playerid, "Question");

	for (new i, j = strlen(inputtext); i < j; i++)
	{
        inputtext[i] = tolower(inputtext[i]);
	}
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_SECURITY_ANSWER], 64);
	format(string, sizeof(string), "成功修改你的安全问题 [Q: %s].", eUser[playerid][e_USER_SECURITY_QUESTION]);
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

CMD:stats(playerid, params[])
{
	new targetid;
	if (sscanf(params, "u", targetid))
	{
  		targetid = playerid;
		SendClientMessage(playerid, COLOR_DEFAULT, "信息: 你需要查看其他玩家信息请使用 /stats [ID]");
	}

	if (!IsPlayerConnected(targetid))
		return SendClientMessage(playerid, COLOR_TOMATO, "该玩家没连接.");

	new name[MAX_PLAYER_NAME];
	GetPlayerName(targetid, name, MAX_PLAYER_NAME);

	new string[150];
	SendClientMessage(playerid, COLOR_GREEN, "_______________________________________________");
	SendClientMessage(playerid, COLOR_GREEN, "");
	format(string, sizeof(string), "%s[%i] 信息: (账户ID: %i)", name, targetid, eUser[targetid][e_USER_SQLID]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	new Float:ratio = ((eUser[targetid][e_USER_DEATHS] < 0) ? (0.0) : (floatdiv(eUser[targetid][e_USER_KILLS], eUser[targetid][e_USER_DEATHS])));

	static levelname[6][25];
	if (!levelname[0][0])
	{
		levelname[0] = "优质玩家";
		levelname[1] = "实习客服";
		levelname[2] = "普通客服";
		levelname[3] = "中阶客服";
		levelname[4] = "高阶客服";
		levelname[5] = "创始人";
	}

	format(string, sizeof (string), "积分: %i || 现金: $%i || 击杀: %i || 死亡: %i || KDA: %0.2f || 管理等级: %i - %s || Vip 等级: %i",
		GetPlayerScore(targetid), GetPlayerMoney(targetid), eUser[targetid][e_USER_KILLS], eUser[targetid][e_USER_DEATHS], ratio, eUser[targetid][e_USER_ADMIN_LEVEL], levelname[((eUser[targetid][e_USER_ADMIN_LEVEL] > 5) ? (5) : (eUser[targetid][e_USER_ADMIN_LEVEL]))], eUser[targetid][e_USER_VIP_LEVEL]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	format(string, sizeof (string), "注册时间: %s || 最后登录: %s",
	 	ReturnTimelapse(eUser[playerid][e_USER_REGISTER_TIMESTAMP], gettime()), ReturnTimelapse(eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);

	SendClientMessage(playerid, COLOR_GREEN, "");
	SendClientMessage(playerid, COLOR_GREEN, "_______________________________________________");
	return 1;
}

stock GetName(playerid)
{
    new PlayerName[MAX_PLAYER_NAME];
    GetPlayerName_fixed(playerid, PlayerName, sizeof(PlayerName));
    return PlayerName;
}

stock GetPlayerName_fixed(playerid, name[], len)
{
	new ret = GetPlayerName( playerid, name, len );
	for( new i=0; name[i]!=0; i++ )
		if( name[i]<0 ) name[i] += 256;
	return ret;
}
