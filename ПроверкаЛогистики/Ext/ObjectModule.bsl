﻿Процедура ВыполнитьПроверку() Экспорт

	УстановитьПривилегированныйРежим(Истина);
	
	СозданиеСлужебнойЗаписки();
	
	Log = "";
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	СервисыЛазурит.Host КАК Host,
		|	СервисыЛазурит.Имя КАК Имя
		|ИЗ
		|	РегистрСведений.СервисыЛазурит КАК СервисыЛазурит
		|ГДЕ
		|	НЕ СервисыЛазурит.ЭтоРЦ";
	
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
	
	Пока ВыборкаДетальныеЗаписи.Следующий() Цикл
		
		ЗапроситьОстаткиРЦНаСервере(СокрЛП(ВыборкаДетальныеЗаписи.Host), СокрЛП(ВыборкаДетальныеЗаписи.Имя), Log);
		ЗапроситьРезервНаСервере(СокрЛП(ВыборкаДетальныеЗаписи.Host), СокрЛП(ВыборкаДетальныеЗаписи.Имя), Log);
		
	КонецЦикла;
	
	Если Log <> "" И Константы.ИспользоватьМониторингЧерезПочту.Получить() Тогда
		
		РО = Справочники.РегиональныеОтделения.ВозвратСсылкиНаПервыйЭлементРО();
	
		Получатель = Константы.ПочтовыйАдресПроверкаЛогистики.Получить();
		Отправитель = Константы.ПочтовыйАдресПроверкаЛогистики.Получить();
		Тема = "Проверка логистики 1С ТОРГ ";
	    Тело = Строка(РО) + Символы.ПС + ТекущаяДата() + Символы.ПС + СтрокаСоединенияИнформационнойБазы() + Символы.ПС + Log;
		
		// определяем массив параметров для процедуры 
		НаборПараметров = Новый Массив;
		НаборПараметров.Добавить(Получатель);
		НаборПараметров.Добавить(Отправитель);
		НаборПараметров.Добавить(Тема);
		НаборПараметров.Добавить(Тело);
		
		////// запуск фонового задания 
		ФоновыеЗадания.Выполнить("ОбщийМодульДляЗапускаФоновыхЗадания.ФоноваяОтправкаПочтовыйСообщений", НаборПараметров);
		
	КонецЕсли;
	
	УстановитьПривилегированныйРежим(Ложь);
	
КонецПроцедуры

Процедура ЗапроситьОстаткиРЦНаСервере(Host, Имя, Log)
	
	ВремяНачала = ТекущаяДата();
	
	Если НЕ ЭтоРаспределительныйЦентр() Тогда
		Возврат;
	КонецЕсли;
	
	ИмяПользователя = "Robot_CDW";
	Пароль = "377852";
	
	СтрокаАвторизации = ПолучитьBase64СтрокуИзДвоичныхДанных(ПолучитьДвоичныеДанныеИзСтроки(ИмяПользователя + ":" + Пароль, КодировкаТекста.UTF8, Ложь));
	
	HTTP = Новый HTTPСоединение(Host, 80, ИмяПользователя, Пароль,,,,Ложь);

	Заголовки = Новый Соответствие();
	
	Заголовки.Вставить("Content-type", "application/JSON;  charset=utf-8");
	
	HTTPЗапрос = Новый HTTPЗапрос("/" + Имя + "/hs/logisticcheck/getremains/" + КодРО(), Заголовки);
	
	Ответ = HTTP.ВызватьHTTPМетод("GET", HTTPЗапрос);
	
	Если Ответ.КодСостояния = 200 Тогда
		ЧтениеJSON = Новый ЧтениеJSON;
		ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
		Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
		ОбработатьДанныеОстатков(Данные, Log);
		
		ВремяОкончания = ТекущаяДата();
			
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Данные получены. Статус-код " + Ответ.КодСостояния);
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Время выполнения: " + (ВремяОкончания - ВремяНачала) / 60 + " мин.");
	Иначе
		Log = Log + "Соединение отсутствует. Статус-код "  + Ответ.КодСостояния + Символы.ПС;
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Соединение отсутствует. Статус-код " + Ответ.КодСостояния);
	КонецЕсли;
	
	Соединение = Неопределено;
	
КонецПроцедуры

Процедура ОбработатьДанныеОстатков(Данные, Log)

	Таблица = Новый ТаблицаЗначений;
	Таблица.Колонки.Добавить("Количество", Новый ОписаниеТипов("Число"));
	Таблица.Колонки.Добавить("Дата", Новый ОписаниеТипов("Дата"));
	Таблица.Колонки.Добавить("Код", Новый ОписаниеТипов("Строка", , , , Новый КвалификаторыСтроки(20)));
	
	Для каждого Элм Из Данные Цикл
		
		нСтр = Таблица.Добавить();
		нСтр.Количество = Число(Элм.Num);
		
		СтрокаДата = СтрЗаменить(Лев(Элм.Date, 10), "-", "");
		нСтр.Дата = Формат(СтрокаДата, "ДЛФ=ДДВ");
		
		нСтр.Код = Элм.Code;
		
	КонецЦикла;
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	Таблица.Код КАК Код,
		|	Таблица.Дата КАК Дата,
		|	Таблица.Количество КАК Количество
		|ПОМЕСТИТЬ втДанные
		|ИЗ
		|	&Таблица КАК Таблица
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	втДанные.Код КАК Код,
		|	втДанные.Дата КАК Дата,
		|	втДанные.Количество КАК Количество,
		|	Номенклатура.Ссылка КАК Номенклатура
		|ПОМЕСТИТЬ втПолученыйРС
		|ИЗ
		|	втДанные КАК втДанные
		|		ЛЕВОЕ СОЕДИНЕНИЕ Справочник.Номенклатура КАК Номенклатура
		|		ПО втДанные.Код = Номенклатура.Код
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	втПолученыйРС.Код КАК Код,
		|	втПолученыйРС.Дата КАК Дата,
		|	втПолученыйРС.Количество КАК Количество,
		|	втПолученыйРС.Номенклатура КАК Номенклатура,
		|	ДоступныеОстаткиВРРО.Номенклатура КАК Номенклатура1,
		|	ДоступныеОстаткиВРРО.ДатаОстатков КАК ДатаОстатков,
		|	ДоступныеОстаткиВРРО.Количество КАК Количество1
		|ПОМЕСТИТЬ вт
		|ИЗ
		|	втПолученыйРС КАК втПолученыйРС
		|		ПОЛНОЕ СОЕДИНЕНИЕ РегистрСведений.ДоступныеОстаткиВРРО КАК ДоступныеОстаткиВРРО
		|		ПО втПолученыйРС.Номенклатура = ДоступныеОстаткиВРРО.Номенклатура
		|			И втПолученыйРС.Дата = ДоступныеОстаткиВРРО.ДатаОстатков
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	вт.Код КАК Код,
		|	вт.Дата КАК Дата,
		|	вт.Количество КАК Количество,
		|	вт.Номенклатура КАК Номенклатура,
		|	вт.Номенклатура1 КАК Номенклатура1,
		|	вт.ДатаОстатков КАК ДатаОстатков,
		|	вт.Количество1 КАК Количество1,
		|	вт.Номенклатура.Представление КАК НоменклатураПредставление,
		|	вт.Номенклатура1.Представление КАК Номенклатура1Представление
		|ИЗ
		|	вт КАК вт
		|ГДЕ
		|	(вт.Номенклатура <> вт.Номенклатура1
		|			ИЛИ вт.Дата <> вт.ДатаОстатков
		|			ИЛИ вт.Количество <> вт.Количество1)";
	
	Запрос.УстановитьПараметр("Таблица", Таблица);
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
	
	Если НЕ РезультатЗапроса.Пустой() Тогда
		Log = Log + "Доступные остатки:" + Символы.ПС;
	КонецЕсли;
	
	Пока ВыборкаДетальныеЗаписи.Следующий() Цикл
		Log = Log + "Не совпадает: " + ВыборкаДетальныеЗаписи.НоменклатураПредставление + "<>" + ВыборкаДетальныеЗаписи.НоменклатураПредставление + Символы.ПС;
	КонецЦикла;
	
	
КонецПроцедуры

Функция КодРО()

	Возврат Справочники.РегиональныеОтделения.ВозвратСсылкиНаПервыйЭлементРО().КонтрагентРО.Код;

КонецФункции

Функция ЭтоРаспределительныйЦентр()

	Возврат Константы.ЭтоРаспределительныйЦентр.Получить();

КонецФункции

Процедура ЗапроситьРезервНаСервере(Host, Имя, Log)
	
	ВремяНачала = ТекущаяДата();
	
	Если НЕ ЭтоРаспределительныйЦентр() Тогда
		Возврат;
	КонецЕсли;
	
	ИмяПользователя = "Robot_CDW";
	Пароль = "377852";
	
	СтрокаАвторизации = ПолучитьBase64СтрокуИзДвоичныхДанных(ПолучитьДвоичныеДанныеИзСтроки(ИмяПользователя + ":" + Пароль, КодировкаТекста.UTF8, Ложь));
	
	HTTP = Новый HTTPСоединение(Host, 80, ИмяПользователя, Пароль,,,,Ложь);

	Заголовки = Новый Соответствие();
	
	Заголовки.Вставить("Content-type", "application/JSON;  charset=utf-8");
	
	HTTPЗапрос = Новый HTTPЗапрос("/" + Имя + "/hs/logisticcheck/getreserve/" + КодРО(), Заголовки);
	
	Ответ = HTTP.ВызватьHTTPМетод("GET", HTTPЗапрос);
	
	Если Ответ.КодСостояния = 200 Тогда
		ЧтениеJSON = Новый ЧтениеJSON;
		ЧтениеJSON.УстановитьСтроку(Ответ.ПолучитьТелоКакСтроку());
		
		Данные = ПрочитатьJSON(ЧтениеJSON, Ложь);
		ОбработатьДанныеРезерва(Данные, Log);
		
		ВремяОкончания = ТекущаяДата();
			
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Данные получены. Статус-код " + Ответ.КодСостояния);
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Время выполнения: " + (ВремяОкончания - ВремяНачала) / 60 + " мин.");
	Иначе
		Log = Log + "Соединение отсутствует. Статус-код "  + Ответ.КодСостояния + Символы.ПС;
		ОбщегоНазначенияКлиентСервер.СообщитьПользователю("Соединение отсутствует. Статус-код " + Ответ.КодСостояния);
	КонецЕсли;
	
	Соединение = Неопределено;
	
КонецПроцедуры

Процедура ОбработатьДанныеРезерва(Данные, Log)

	Таблица = Новый ТаблицаЗначений;
	Таблица.Колонки.Добавить("Количество", Новый ОписаниеТипов("Число"));
	Таблица.Колонки.Добавить("Дата", Новый ОписаниеТипов("Дата"));
	Таблица.Колонки.Добавить("Код", Новый ОписаниеТипов("Строка", , , , Новый КвалификаторыСтроки(20)));
	Таблица.Колонки.Добавить("КодРО", Новый ОписаниеТипов("Строка", , , , Новый КвалификаторыСтроки(9)));
	
	Для каждого Элм Из Данные Цикл
		
		нСтр = Таблица.Добавить();
		нСтр.Количество = Число(Элм.Num);
		
		СтрокаДата = СтрЗаменить(Лев(Элм.Date, 10), "-", "");
		нСтр.Дата = Формат(СтрокаДата, "ДЛФ=ДДВ");
		
		нСтр.Код = Элм.Code;
		нСтр.КодРО = Элм.CodeRO;
		
	КонецЦикла;
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	Таблица.Код КАК Код,
		|	Таблица.КодРО КАК КодРО,
		|	Таблица.Дата КАК Дата,
		|	Таблица.Количество КАК Количество
		|ПОМЕСТИТЬ втДанные
		|ИЗ
		|	&Таблица КАК Таблица
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	втДанные.Код КАК Код,
		|	втДанные.КодРО КАК КодРО,
		|	втДанные.Дата КАК Дата,
		|	втДанные.Количество КАК Количество,
		|	Номенклатура.Ссылка КАК Номенклатура,
		|	Контрагенты.Ссылка КАК РО
		|ПОМЕСТИТЬ втПолученыйрезерв
		|ИЗ
		|	втДанные КАК втДанные
		|		ЛЕВОЕ СОЕДИНЕНИЕ Справочник.Номенклатура КАК Номенклатура
		|		ПО втДанные.Код = Номенклатура.Код
		|		ЛЕВОЕ СОЕДИНЕНИЕ Справочник.Контрагенты КАК Контрагенты
		|		ПО втДанные.КодРО = Контрагенты.Код
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	втПолученыйрезерв.Код КАК Код,
		|	втПолученыйрезерв.Дата КАК Дата,
		|	втПолученыйрезерв.Количество КАК Количество,
		|	втПолученыйрезерв.Номенклатура КАК Номенклатура,
		|	РезервРРООстатки.Номенклатура КАК Номенклатура1,
		|	РезервРРООстатки.ДатаЗаказаВРРО КАК ДатаЗаказаВРРО,
		|	РезервРРООстатки.КоличествоОстаток КАК КоличествоОстаток
		|ПОМЕСТИТЬ вт
		|ИЗ
		|	втПолученыйрезерв КАК втПолученыйрезерв
		|		ПОЛНОЕ СОЕДИНЕНИЕ РегистрНакопления.РезервРРО.Остатки(, ) КАК РезервРРООстатки
		|		ПО втПолученыйрезерв.Номенклатура = РезервРРООстатки.Номенклатура
		|			И втПолученыйрезерв.Дата = РезервРРООстатки.ДатаЗаказаВРРО
		|			И втПолученыйрезерв.РО = РезервРРООстатки.Контрагент
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|ВЫБРАТЬ
		|	вт.Код КАК Код,
		|	вт.Дата КАК Дата,
		|	вт.Количество КАК Количество,
		|	вт.Номенклатура КАК Номенклатура,
		|	вт.Номенклатура1 КАК Номенклатура1,
		|	вт.Номенклатура.Представление КАК НоменклатураПредставление,
		|	вт.Номенклатура1.Представление КАК Номенклатура1Представление,
		|	вт.ДатаЗаказаВРРО КАК ДатаЗаказаВРРО,
		|	вт.КоличествоОстаток КАК КоличествоОстаток
		|ИЗ
		|	вт КАК вт
		|ГДЕ
		|	(вт.Номенклатура <> вт.Номенклатура1
		|			ИЛИ вт.Дата <> вт.ДатаЗаказаВРРО
		|			ИЛИ вт.Количество <> вт.КоличествоОстаток)";
	
	Запрос.УстановитьПараметр("Таблица", Таблица);
	РезультатЗапроса = Запрос.Выполнить();
	
	ВыборкаДетальныеЗаписи = РезультатЗапроса.Выбрать();
	
	Если НЕ РезультатЗапроса.Пустой() Тогда
		Log = Log + "Резерв РРО:" + Символы.ПС;
	КонецЕсли;
	
	Пока ВыборкаДетальныеЗаписи.Следующий() Цикл
		Log = Log + "Не совпадает: " + ВыборкаДетальныеЗаписи.НоменклатураПредставление + "<>" + ВыборкаДетальныеЗаписи.НоменклатураПредставление + Символы.ПС;
	КонецЦикла;
	
	
КонецПроцедуры

Процедура СозданиеСлужебнойЗаписки()

	Если ЭтоРаспределительныйЦентр() Тогда
		Возврат;
	КонецЕсли;
	
	Запрос = Новый Запрос;
	Запрос.Текст = 
		"ВЫБРАТЬ
		|	ПериодыПоставкиСФабрикПоОфисам.Фабрика.Представление КАК Представление,
		|	"""" КАК ПредставлениеДоп,
		|	""Дата заказа менее текущей даты"" КАК Сообщение
		|ИЗ
		|	РегистрСведений.ПериодыПоставкиСФабрикПоОфисам КАК ПериодыПоставкиСФабрикПоОфисам
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ПериодыПоставкиСФабрикПоОфисам.Фабрика.Представление,
		|	"""",
		|	""Запись не уникальна""
		|ИЗ
		|	РегистрСведений.ПериодыПоставкиСФабрикПоОфисам КАК ПериодыПоставкиСФабрикПоОфисам
		|
		|СГРУППИРОВАТЬ ПО
		|	ПериодыПоставкиСФабрикПоОфисам.Фабрика.Представление
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ПериодыПоставкиСФабрикПоОфисам.Фабрика.Представление,
		|	"""",
		|	""Не заполнен Период поставки с фабрики""
		|ИЗ
		|	РегистрСведений.ПериодыПоставкиСФабрикПоОфисам КАК ПериодыПоставкиСФабрикПоОфисам
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ПериодыПоставкиСФабрикПоОфисам.Фабрика.Представление,
		|	"""",
		|	""Не заполнен Период поставки до РЦ""
		|ИЗ
		|	РегистрСведений.ПериодыПоставкиСФабрикПоОфисам КАК ПериодыПоставкиСФабрикПоОфисам
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ДатыОтгрузокВДО.Офис.Представление,
		|	МАКСИМУМ(ДатыОтгрузокВДО.ДатаЗаказаВЦО),
		|	""Дата заказа в ЦО меньше текущей даты +180""
		|ИЗ
		|	РегистрСведений.ДатыОтгрузокВДО КАК ДатыОтгрузокВДО
		|ГДЕ
		|	ДатыОтгрузокВДО.ДатаЗаказаВЦО < ДОБАВИТЬКДАТЕ(&ТекущаяДата, ДЕНЬ, 180)
		|
		|СГРУППИРОВАТЬ ПО
		|	ДатыОтгрузокВДО.Офис.Представление
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ДатыЗаказаРРО.РаспределительныйЦентр.Представление,
		|	МАКСИМУМ(ДатыЗаказаРРО.ДатаЗаказаРРО),
		|	""Дата заказа в РЦ меньше текущей даты +180""
		|ИЗ
		|	РегистрСведений.ДатыЗаказаРРО КАК ДатыЗаказаРРО
		|ГДЕ
		|	ДатыЗаказаРРО.ДатаЗаказаРРО < ДОБАВИТЬКДАТЕ(&ТекущаяДата, ДЕНЬ, 180)
		|
		|СГРУППИРОВАТЬ ПО
		|	ДатыЗаказаРРО.РаспределительныйЦентр.Представление
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	УчетЛогистическихОперацийОстатки.Документ.Представление,
		|	УчетЛогистическихОперацийОстатки.Номенклатура.Представление,
		|	""Остаток ЛО на дату доставки меньшей текущей""
		|ИЗ
		|	РегистрНакопления.УчетЛогистическихОпераций.Остатки(, ДатаДоставки < &ТекущаяДата) КАК УчетЛогистическихОперацийОстатки
		|ГДЕ
		|	ЕСТЬNULL(УчетЛогистическихОперацийОстатки.КоличествоОстаток, 0) <> 0
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	УчетЛогистическихОперацийОстатки.Документ.Представление,
		|	УчетЛогистическихОперацийОстатки.Номенклатура.Представление,
		|	""Остаток ЛО на дату доставки ≥ текущей""
		|ИЗ
		|	РегистрНакопления.УчетЛогистическихОпераций.Остатки(, ДатаДоставки >= &ТекущаяДата) КАК УчетЛогистическихОперацийОстатки
		|ГДЕ
		|	ЕСТЬNULL(УчетЛогистическихОперацийОстатки.КоличествоОстаток, 0) < 0
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	УпаковкиДляСРКОстатки.Номенклатура.Представление,
		|	"""",
		|	""Остаток Упаковок СРК на дату меньшей текущей""
		|ИЗ
		|	РегистрНакопления.УпаковкиДляСРК.Остатки(, ДатаЛО < &ТекущаяДата) КАК УпаковкиДляСРКОстатки
		|ГДЕ
		|	ЕСТЬNULL(УпаковкиДляСРКОстатки.КоличествоОстаток, 0) > 0
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	ЗаказыПоставщикамТМЦОстатки.ЗаказПоставщику.Представление,
		|	ЗаказыПоставщикамТМЦОстатки.Номенклатура.Представление,
		|	""Остаток закозов ТМЦ на дату меньшей текущей""
		|ИЗ
		|	РегистрНакопления.ЗаказыПоставщикамТМЦ.Остатки(, ДатаПрихода < &ТекущаяДата) КАК ЗаказыПоставщикамТМЦОстатки
		|ГДЕ
		|	ЕСТЬNULL(ЗаказыПоставщикамТМЦОстатки.КоличествоОстаток, 0) > 0
		|
		|ОБЪЕДИНИТЬ ВСЕ
		|
		|ВЫБРАТЬ
		|	&КоличествоРЦ,
		|	"""",
		|	ВЫБОР
		|		КОГДА КОЛИЧЕСТВО(РАЗЛИЧНЫЕ ОчередностьРаспределительныхЦентров.РаспределительныйЦентр) > &КоличествоРЦ
		|			ТОГДА ""Количество записей больше ""
		|		КОГДА КОЛИЧЕСТВО(РАЗЛИЧНЫЕ ОчередностьРаспределительныхЦентров.РаспределительныйЦентр) < &КоличествоРЦ
		|			ТОГДА ""Количество записей меньше ""
		|	КОНЕЦ
		|ИЗ
		|	РегистрСведений.ОчередностьРаспределительныхЦентров КАК ОчередностьРаспределительныхЦентров
		|
		|ИМЕЮЩИЕ
		|	КОЛИЧЕСТВО(РАЗЛИЧНЫЕ ОчередностьРаспределительныхЦентров.РаспределительныйЦентр) <> &КоличествоРЦ";
	
	Запрос.УстановитьПараметр("КоличествоРЦ", Константы.КоличествоРЦ.Получить());
	Запрос.УстановитьПараметр("ТекущаяДата", НачалоДня(ТекущаяДата()));
	
	РезультатЗапроса = Запрос.Выполнить();
	
	Если РезультатЗапроса.Пустой() Тогда
	
		Возврат;
	
	КонецЕсли;
	
	СлужебнаяЗаписка = Документы.СлужебнаяЗаписка.СоздатьДокумент();
	СлужебнаяЗаписка.Дата = ТекущаяДата();
	СлужебнаяЗаписка.ВидСлужебнойЗаписки = Справочники.ВидСлужебнойЗапискиВнутр.ПроверкаЛогистикиРО;
	
	Выборка = РезультатЗапроса.Выбрать();
	
	Пока Выборка.Следующий() Цикл
		
		Комментарии = СлужебнаяЗаписка.Комментарии.Добавить();
		Сообщение = Выборка.Сообщение + ", " + Выборка.Представление;
		
		Если Выборка.ПредставлениеДоп <> "" Тогда
			Сообщение = Сообщение  + ", " + Выборка.ПредставлениеДоп;
		КонецЕсли;
		
		Комментарии.ТекстКомментария = Сообщение;
	
	КонецЦикла;
	
	СлужебнаяЗаписка.Записать(РежимЗаписиДокумента.Проведение);

КонецПроцедуры
