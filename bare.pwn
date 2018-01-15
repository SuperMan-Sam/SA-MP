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

//#define SECURE_PASSWORD_ONLY // ���ǿ���û�����������������1��Сд��ĸ��1����д��ĸ��1������

#define MAX_SECURITY_QUESTION_SIZE 256

new MySQL:conn;

new const SECURITY_QUESTIONS[][MAX_SECURITY_QUESTION_SIZE] =
{
	"1",
	"2"
	/*"���С����?",
	"���ͯ������������?",
	"��ļ���������?",
	"�㺢�ӵ�С����?",
	"����ϲ���ĸ��������?",
	"����ϲ���ĵ�Ӱ��?",
	"����ǵ��к���Ů��������?",
	"��ĵ�һ������Ʒ�ƺ��ͺ���?",
	"�������ҽԺ��?",
	"˭�����ͯ�����Ͽɵ�Ӣ��?",
	"��ĵ�һ�ݹ�������?",
	"��ĵ�һ�ݹ�����?",
	"��Сѧ���ĸ�ѧУ?",
	"��Сѧ��ϲ������ʦ��?"*/
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
		format(ret, sizeof(ret), "һ��");
	if (seconds < (1 * MINUTE))
		format(ret, sizeof(ret), "%i ��", seconds);
	else if (seconds < (2 * MINUTE))
		format(ret, sizeof(ret), "һ����");
	else if (seconds < (45 * MINUTE))
		format(ret, sizeof(ret), "%i ����", (seconds / MINUTE));
	else if (seconds < (90 * MINUTE))
		format(ret, sizeof(ret), "һСʱ");
	else if (seconds < (24 * HOUR))
		format(ret, sizeof(ret), "%i Сʱ", (seconds / HOUR));
	else if (seconds < (48 * HOUR))
		format(ret, sizeof(ret), "һ��");
	else if (seconds < (30 * DAY))
		format(ret, sizeof(ret), "%i ��", (seconds / DAY));
	else if (seconds < (12 * MONTH))
    {
		new months = floatround(seconds / DAY / 30);
      	if (months <= 1)
			format(ret, sizeof(ret), "һ��");
      	else
			format(ret, sizeof(ret), "%i ��", months);
	}
    else
    {
      	new years = floatround(seconds / DAY / 365);
      	if (years <= 1)
			format(ret, sizeof(ret), "һ��");
      	else
			format(ret, sizeof(ret), "%i ��", years);
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
	SendClientMessage(playerid, COLOR_YELLOW, "���������� \"SA-MP 0.3.7 ������\"");
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

		Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "�˻�ע��... [����: 1/3]", COL_WHITE "��ӭ�������ǵķ�����. ���ǻ���� "COL_GREEN"3 ���򵥵Ĳ��� "COL_WHITE"��ע������˻�!\n�������������, "COL_TOMATO"Ȼ����"COL_WHITE" ȷ��.", "ȷ��", "ѡ��");
		SendClientMessage(playerid, COLOR_WHITE, "[����: 1/3] ����������˻�����.");
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
		        SendClientMessage(playerid, COLOR_TOMATO, "��Ǹ! ����˻���������. �������� "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS".");
		        format(string, sizeof(string), "ʣ�ೢ������ %s.", ReturnTimelapse(gettime(), lock_timestamp));
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

		Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "�˻���¼...", COL_WHITE "�������������ʸ��˻�. ����㳢�� "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"��, �˻��������� "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"����.", "ȷ��", "ѡ��");
	}
	return 1;
}

Dialog:LOGIN(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
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

		    SendClientMessage(playerid, COLOR_TOMATO, "��Ǹ! ����˻���������. �������� "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS".");
		    format(string, sizeof(string), "���������������/�û����������´ε�¼�����е����ѡ� (�˻��ѱ����� %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    Dialog_Show(playerid, LOGIN, DIALOG_STYLE_INPUT, "�˻���½...", COL_WHITE "�������������ʸ��˻�. ����㳢�Դ������� "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"��,�˻��������� "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"����.", "ȷ��", "ѡ��");
	    format(string, sizeof(string), "��������! �㳢�Ե�¼: %i/"#MAX_LOGIN_ATTEMPTS" ��.", iLoginAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	new name[MAX_PLAYER_NAME],
		ip[18];
	GetPlayerName(playerid, name, MAX_PLAYER_NAME);
	GetPlayerIp(playerid, ip, 18);
	mysql_format(conn, string, sizeof(string), "UPDATE `users` SET `lastlogin_timestamp` = %i, `ip` = '%s', `longip` = %i WHERE `id` = %i", gettime(), ip, IpToLong(ip), eUser[playerid][e_USER_SQLID]);
	mysql_tquery(conn, string);

	format(string, sizeof(string), "�ɹ���¼! ��ӭ�ص� %s, �������������һ��. [����¼: %s ǰ]", name, ReturnTimelapse(eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP], gettime()));
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
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
	    return 1;
	}

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "�˻�ע��... [����: 1/3]", COL_WHITE "��ӭ����. ���ǽ��ṩ "COL_GREEN"3 ���򵥲��� "COL_WHITE"��ע������˻�,��������������������·�ѡ��˵�!\n��������Ҫע�������, "COL_TOMATO"���ִ�Сд"COL_WHITE".", "ȷ��", "ѡ��");
		SendClientMessage(playerid, COLOR_TOMATO, "���볤����Ч������Ҫ�� "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" �ַ�.");
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
		    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_INPUT, "�˻�ע��... [����: 1/3]", COL_WHITE "��ӭ����. ���ǻ��ṩ "COL_GREEN"3 ���򵥲��� "COL_WHITE"��ע���˻�,�����������������������·�ѡ��˵�!\n��������Ҫע����������ע��, "COL_TOMATO"���ִ�Сд"COL_WHITE".", "ȷ��", "ѡ��");
			SendClientMessage(playerid, COLOR_TOMATO, "�����ַ��������һ����ĸ������.");
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
	Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "�˻�ע��... [����: 2/3]", list, "ȷ��", "����");
	SendClientMessage(playerid, COLOR_WHITE, "[����: 2/3] ��ѡ��һ����ȫ����. �⽫��������˻���ȫ,��ֹ�˻������Լ���������!");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:SEC_QUESTION(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, REGISTER, DIALOG_STYLE_INPUT, "�˻�ע��... [����: 1/3]", COL_WHITE "��ӭ����. ���ǻ��ṩ "COL_GREEN"3 ���򵥲��� "COL_WHITE"��ע���˻�,�����������������������·�ѡ��˵�!\n��������Ҫע����������ע��, "COL_TOMATO"���ִ�Сд"COL_WHITE".", "ȷ��", "ѡ��");
		SendClientMessage(playerid, COLOR_WHITE, "[����: 1/3] �����������ʻ�������.");
		return 1;
	}

	format(eUser[playerid][e_USER_SECURITY_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[listitem]);

	new string[256];
	format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"���·�������д��İ�ȫ�����. (�޴�Сд����).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "�˻�ע��... [����: 3/3]", string, "ȷ��", "����");
	SendClientMessage(playerid, COLOR_WHITE, "[����: 3/3] д����İ�ȫ����Ĵ𰸣��������� :)");
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
		Dialog_Show(playerid, SEC_QUESTION, DIALOG_STYLE_LIST, "�˻�ע��... [����: 2/3]", list, "ȷ��", "����");
		SendClientMessage(playerid, COLOR_WHITE, "[����: 2/3] ��ѡ��һ����ȫ����. �⽫��������˻���ȫ,��ֹ�˻������Լ���������!");
		return 1;
	}

	new string[1024];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_TOMATO "%s\n"COL_WHITE"���·�������д��İ�ȫ�����. (�޴�Сд����).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, SEC_ANSWER, DIALOG_STYLE_INPUT, "�˻�ע��... [����: 3/3]", string, "ȷ��", "����");
		SendClientMessage(playerid, COLOR_TOMATO, "��ȫ�𰸲������� "#MIN_PASSWORD_LENGTH" �ַ�.");
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

	format(string, sizeof(string), "�ɹ�ע��! ��ӭ���� %s, �������������һ��. [IP: %s]", name, ip);
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
			Dialog_Show(playerid, LOGIN, DIALOG_STYLE_PASSWORD, "�ʻ���¼...", COL_WHITE "���������������˻�. ����㳢�Դ����ﵽ "COL_YELLOW""#MAX_LOGIN_ATTEMPTS" "COL_WHITE"�˻��������� "COL_YELLOW""#MAX_ACCOUNT_LOCKTIME" "COL_WHITE"����.", "ȷ��", "ѡ��");
		else
			Dialog_Show(playerid, REGISTER, DIALOG_STYLE_PASSWORD, "�˻�ע��... [����: 1/3]", COL_WHITE "��ӭ����������,���ǻ��ṩ "COL_GREEN"3 ���򵥲��� "COL_WHITE"ע������˻�!\n��������Ҫע�������, "COL_TOMATO"���ִ�Сд"COL_WHITE".", "ȷ��", "ѡ��");
		return 1;
	}

	switch (listitem)
	{
	    case 0:
	    {
	        if (eUser[playerid][e_USER_SQLID] == -1)
	        {
	            SendClientMessage(playerid, COLOR_TOMATO, "���˻�δע��,������־����������˻����Ե�������û���ѡ��.");
	        	Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
	        	return 1;
	        }

			new string[64 + MAX_SECURITY_QUESTION_SIZE];
			format(string, sizeof(string), COL_WHITE "�ش����İ�ȫ��������������.\n\n"COL_TOMATO"%s", eUser[playerid][e_USER_SECURITY_QUESTION]);
			Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "��������:", string, "��һ��", "ȡ��");
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
		SendClientMessage(playerid, COLOR_TOMATO, "���˻�δ��֤��ĵ���,���������ĵ�һ�ε�½!");
		Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
		return;
	}

	new list[25 * (MAX_PLAYER_NAME + 32)],
		name[MAX_PLAYER_NAME],
		lastlogin_timestamp;

	for (new i, j = ((cache_num_rows() > 10) ? (10) : (cache_num_rows())); i < j; i++)
	{
		cache_get_value_index(i, 0, name, MAX_PLAYER_NAME);
		cache_get_value_index_int(i, 1, lastlogin_timestamp);
	    format(list, sizeof(list), "%s"COL_TOMATO"%s "COL_WHITE"|| ����¼: %s ǰ\n", list, name, ReturnTimelapse(lastlogin_timestamp, gettime()));
	}
	cache_unset_active();

	Dialog_Show(playerid, FORGOT_USERNAME, DIALOG_STYLE_LIST, "����û�����ʷ...", list, "Ok", "");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
}

Dialog:FORGOT_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
	    Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
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

		    SendClientMessage(playerid, COLOR_TOMATO, "��Ǹ! ���˻�����ֹ����ĵ����ϵ�½ "#MAX_LOGIN_ATTEMPTS"/"#MAX_LOGIN_ATTEMPTS" ʧ�ܳ���.");
		    format(string, sizeof(string), "������������������/�û���,������ڵ�¼����ѡ��`ѡ��`����������֤ (�㳢�� %s).", ReturnTimelapse(gettime(), lock_timestamp));
			SendClientMessage(playerid, COLOR_TOMATO, string);
		    return Kick(playerid);
		}

	    format(string, sizeof(string), COL_WHITE "�ش����İ�ȫ��������������.\n\n"COL_TOMATO"%s", eUser[playerid][e_USER_SECURITY_QUESTION]);
		Dialog_Show(playerid, FORGOT_PASSWORD, DIALOG_STYLE_INPUT, "��������:", string, "��һ��", "ȡ��");
		format(string, sizeof(string), "�����: %i/"#MAX_LOGIN_ATTEMPTS" ����.", iAnswerAttempts[playerid]);
		SendClientMessage(playerid, COLOR_TOMATO, string);
	    return 1;
	}

	Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "��������:", COL_WHITE "����һ���µ��˻�����,��������޸�����˻���ȫ����,��ʹ��/ucp.", "ȷ��", "");
	SendClientMessage(playerid, COLOR_GREEN, "�ɹ���֤�����İ�ȫ���⣡ �����ڿ��������������.");
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:RESET_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
	{
		Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "��������:", COL_WHITE "����һ���µ��˻�����,��������޸�����˻���ȫ����,��ʹ��/ucp.", "ȷ��", "");
		return 1;
	}

	new string[256];

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "��������:", COL_WHITE "����һ���µ��˻�����,��������޸�����˻���ȫ����,��ʹ��/ucp.", "ȷ��", "");
		SendClientMessage(playerid, COLOR_TOMATO, "����ֻ�ܴ��� "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" �ַ�.");
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
		    Dialog_Show(playerid, RESET_PASSWORD, DIALOG_STYLE_PASSWORD, "R��������:", COL_WHITE "����һ���µ��˻�����,��������޸�����˻���ȫ����,��ʹ��/ucp.", "ȷ��", "");
			SendClientMessage(playerid, COLOR_TOMATO, "�����ַ�����, ���������ĸ������.");
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

	format(string, sizeof(string), "�ɹ�ʹ���������¼! ��ӭ�ص������� %s, �������������һ��. [����¼ʱ��: %s ǰ]", name, ReturnTimelapse(eUser[playerid][e_USER_LASTLOGIN_TIMESTAMP], gettime()));
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	SetPVarInt(playerid, "LoggedIn", 1);
	OnPlayerRequestClass(playerid, 0);
	return 1;
}

Dialog:FORGOT_USERNAME(playerid, response, listitem, inputtext[])
{
	Dialog_Show(playerid, OPTIONS, DIALOG_STYLE_LIST, "�˻�ѡ��...", "��������\n�����û���\n�˳���Ϸ", "ѡ��", "����");
	return 1;
}

CMD:changepass(playerid, params[])
{
	if (eUser[playerid][e_USER_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "ֻ��ע���û���ʹ�ø�ָ��.");
		return 1;
	}

    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "�޸��˻�����...", COL_WHITE "�޸��˻����� "COL_YELLOW"���ִ�Сд"COL_WHITE".", "ȷ��", "ȡ��");
	SendClientMessage(playerid, COLOR_WHITE, "����������.");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_PASSWORD(playerid, response, listitem, inputtext[])
{
	if (!response)
		return 1;

	if (!(MIN_PASSWORD_LENGTH <= strlen(inputtext) <= MAX_PASSWORD_LENGTH))
	{
	    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_PASSWORD, "�޸��˻�����...", COL_WHITE "�޸��˻����� "COL_YELLOW"���ִ�Сд"COL_WHITE".", "ȷ��", "ȡ��");
		SendClientMessage(playerid, COLOR_TOMATO, "������Ч,���� "#MIN_PASSWORD_LENGTH" - "#MAX_PASSWORD_LENGTH" �ַ�.");
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
		    Dialog_Show(playerid, CHANGE_PASSWORD, DIALOG_STYLE_INPUT, "�޸��˻�����...", COL_WHITE "�޸�����˻����� "COL_YELLOW"���ִ�Сд"COL_WHITE".", "ȷ��", "ȡ��");
			SendClientMessage(playerid, COLOR_TOMATO, "������뺬����ĸ������.");
		    return 1;
		}
	#endif

	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_PASSWORD], 129);

	new string[256];
	for (new i, j = strlen(inputtext); i < j; i++)
	{
	    inputtext[i] = '*';
	}
	format(string, sizeof(string), "�ɹ��޸��������. [P: %s]", inputtext);
	SendClientMessage(playerid, COLOR_GREEN, string);
	PlayerPlaySound(playerid, 1057, 0.0, 0.0, 0.0);
	return 1;
}

CMD:changeques(playerid, params[])
{
	if (eUser[playerid][e_USER_SQLID] != 1)
	{
		SendClientMessage(playerid, COLOR_TOMATO, "ֻ��ע���û�����ʹ���������.");
		return 1;
	}

    new list[2 + (sizeof(SECURITY_QUESTIONS) * MAX_SECURITY_QUESTION_SIZE)];
	for (new i; i < sizeof(SECURITY_QUESTIONS); i++)
	{
	    strcat(list, SECURITY_QUESTIONS[i]);
	    strcat(list, "\n");
	}
	Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "�޸��˻���ȫ����... [����: 1/2]", list, "ȷ��", "ȡ��");
	SendClientMessage(playerid, COLOR_WHITE, "[����: 1/2] ����дһ����ȫ���⼰�ش�,���������˻���ȫ!");
	PlayerPlaySound(playerid, 1054, 0.0, 0.0, 0.0);
	return 1;
}

Dialog:CHANGE_SEC_QUESTION(playerid, response, listitem, inputext[])
{
	if (!response)
		return 1;

	SetPVarInt(playerid, "Question", listitem);

	new string[256];
	format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"�����·���д��������. (�𰸲��ִ�Сд).", SECURITY_QUESTIONS[listitem]);
	Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "�޸��˻���ȫ����... [����: 2/2]", string, "ȷ��", "����");
	SendClientMessage(playerid, COLOR_WHITE, "[����: 2/2] д����İ�ȫ����Ĵ�.");
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
		Dialog_Show(playerid, CHANGE_SEC_QUESTION, DIALOG_STYLE_LIST, "�޸��˻���ȫ����... [����: 1/2]", list, "ȷ��", "ȡ��");
		SendClientMessage(playerid, COLOR_WHITE, "[����: 1/2] ����дһ����ȫ���⼰�ش�,���������˻���ȫ!");
		return 1;
	}

	new string[512];

	if (strlen(inputtext) < MIN_PASSWORD_LENGTH || inputtext[0] == ' ')
	{
	    format(string, sizeof(string), COL_YELLOW "%s\n"COL_WHITE"�����·���д��������. (�𰸲��ִ�Сд).", SECURITY_QUESTIONS[listitem]);
		Dialog_Show(playerid, CHANGE_SEC_ANSWER, DIALOG_STYLE_INPUT, "�޸��˻���ȫ����... [����: 2/2]", string, "ȷ��", "����");
		SendClientMessage(playerid, COLOR_TOMATO, "�𰸲������� "#MIN_PASSWORD_LENGTH" �ַ�.");
		return 1;
	}

	format(eUser[playerid][e_USER_SECURITY_QUESTION], MAX_SECURITY_QUESTION_SIZE, SECURITY_QUESTIONS[GetPVarInt(playerid, "Question")]);
	DeletePVar(playerid, "Question");

	for (new i, j = strlen(inputtext); i < j; i++)
	{
        inputtext[i] = tolower(inputtext[i]);
	}
	SHA256_PassHash(inputtext, eUser[playerid][e_USER_SALT], eUser[playerid][e_USER_SECURITY_ANSWER], 64);
	format(string, sizeof(string), "�ɹ��޸���İ�ȫ���� [Q: %s].", eUser[playerid][e_USER_SECURITY_QUESTION]);
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
		SendClientMessage(playerid, COLOR_DEFAULT, "��Ϣ: ����Ҫ�鿴���������Ϣ��ʹ�� /stats [ID]");
	}

	if (!IsPlayerConnected(targetid))
		return SendClientMessage(playerid, COLOR_TOMATO, "�����û����.");

	new name[MAX_PLAYER_NAME];
	GetPlayerName(targetid, name, MAX_PLAYER_NAME);

	new string[150];
	SendClientMessage(playerid, COLOR_GREEN, "_______________________________________________");
	SendClientMessage(playerid, COLOR_GREEN, "");
	format(string, sizeof(string), "%s[%i] ��Ϣ: (�˻�ID: %i)", name, targetid, eUser[targetid][e_USER_SQLID]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	new Float:ratio = ((eUser[targetid][e_USER_DEATHS] < 0) ? (0.0) : (floatdiv(eUser[targetid][e_USER_KILLS], eUser[targetid][e_USER_DEATHS])));

	static levelname[6][25];
	if (!levelname[0][0])
	{
		levelname[0] = "�������";
		levelname[1] = "ʵϰ�ͷ�";
		levelname[2] = "��ͨ�ͷ�";
		levelname[3] = "�н׿ͷ�";
		levelname[4] = "�߽׿ͷ�";
		levelname[5] = "��ʼ��";
	}

	format(string, sizeof (string), "����: %i || �ֽ�: $%i || ��ɱ: %i || ����: %i || KDA: %0.2f || ����ȼ�: %i - %s || Vip �ȼ�: %i",
		GetPlayerScore(targetid), GetPlayerMoney(targetid), eUser[targetid][e_USER_KILLS], eUser[targetid][e_USER_DEATHS], ratio, eUser[targetid][e_USER_ADMIN_LEVEL], levelname[((eUser[targetid][e_USER_ADMIN_LEVEL] > 5) ? (5) : (eUser[targetid][e_USER_ADMIN_LEVEL]))], eUser[targetid][e_USER_VIP_LEVEL]);
	SendClientMessage(playerid, COLOR_GREEN, string);

	format(string, sizeof (string), "ע��ʱ��: %s || ����¼: %s",
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
