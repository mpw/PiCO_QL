#include "search.h"
#include <string>
#include <assert.h>
#include <stdio.h>
#include <string>

#include "Truck.h"
#include "Customer.h"

using namespace std;


/*
#define DEBUGGING
*/

struct name_cmp {
    bool operator()(const char *a, const char *b) {
	return strcmp(a, b) < 0;
    }
};

static map<const char *, int, name_cmp> vt_directory;
static map<const char *, int>::iterator vtd_iter;

void register_vt(const char *vt_name) {
    vt_directory[vt_name] = 0;
}

int get_datastructure_size(sqlite3_vtab_cursor *cur){
    stlTableCursor *stc = (stlTableCursor *)cur;
    stlTable *stl = (stlTable *)cur->pVtab;
    if( !strcmp(stl->zName, "Trucks") ){
        vector<Truck*> *any_dstr = (vector<Truck*> *)stc->source;
        return ((int)any_dstr->size());
    }
    if( !strcmp(stl->zName, "Customers") ){
        vector<Customer*> *any_dstr = (vector<Customer*> *)stc->source;
        return ((int)any_dstr->size());
    }
    if( !strcmp(stl->zName, "MapIndex") ){
        map<int,Customer*> *any_dstr = (map<int,Customer*> *)stc->source;
        return ((int)any_dstr->size());
    }
    return 1;
}


int realloc_resultset(sqlite3_vtab_cursor *cur) {
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    int arraySize;
    int *res;
    arraySize = get_datastructure_size(cur);
    if ( arraySize != stcsr->max_size ){
        res = (int *)sqlite3_realloc(stcsr->resultSet, sizeof(int) * arraySize);
        if (res!=NULL){
            stcsr->resultSet = res;
            memset(stcsr->resultSet, -1,
                   sizeof(int) * arraySize);
            stcsr->max_size = arraySize;
#ifdef DEBUGGING
            printf("\nReallocating resultSet..now max size %i \n\n", stcsr->max_size);
#endif
        }else{
            sqlite3_free(res);
            printf("Error (re)allocating memory\n");
            return SQLITE_NOMEM;
        }
    }
    return SQLITE_OK;
}


int compare(int dstr_value, int op, int value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int compare(long int dstr_value, int op, long int value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int compare(double dstr_value, int op, double value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int compare(const void *dstr_value, int op, const void *value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int compare(const unsigned char *dstr_value, int op,
                   const unsigned char *value){
    switch( op ){
    case 0:
        return strcmp((const char *)dstr_value,(const char *)value)<0;
    case 1:
        return strcmp((const char *)dstr_value,(const char *)value)<=0;
    case 2:
        return strcmp((const char *)dstr_value,(const char *)value)==0;
    case 3:
        return strcmp((const char *)dstr_value,(const char *)value)>=0;
    case 4:
        return strcmp((const char *)dstr_value,(const char *)value)>0;
    }
}


int compare_res(int count, stlTableCursor *stcsr, int *temp_res) {
    int ia, ib;
    int *i_res;
    int i_count = 0;
    if ( (stcsr->size == 0) && (stcsr->first_constr == 1) ){
        memcpy(stcsr->resultSet, temp_res, sizeof(int) *
               stcsr->max_size);
        stcsr->size = count;
        stcsr->first_constr = 0;
    }else if (stcsr->size > 0){
        i_res = (int *)sqlite3_malloc(sizeof(int) *
                                      stcsr->max_size);
        if ( i_res == NULL ) {
            sqlite3_free(i_res);
            printf("Error (re)allocating memory\n");
            return SQLITE_NOMEM;
        }
        for(int a=0; a<stcsr->size; a++){
            for(int b=0; b<count; b++){
                ia = stcsr->resultSet[a];
                ib = temp_res[b];
                if( ia==ib ){
                    i_res[i_count++] = ia;
                }else if( ia < ib )
                    b = count;
            }
        }
        assert( i_count <= stcsr->max_size );
        memcpy(stcsr->resultSet, i_res, sizeof(int) *
               i_count);
        stcsr->size = i_count;
        sqlite3_free(i_res);
    }
    return SQLITE_OK;
}


void check_alloc(const char *constr, int &op, int &iCol) {
    switch( constr[0] - 'A' ){
    case 0:
        op = 0;
        break;
    case 1:
        op = 1;
        break;
    case 2:
        op = 2;
        break;
    case 3:
        op = 3;
        break;
    case 4:
        op = 4;
        break;
    case 5:
        op = 5;
        break;
    default:
        break;
    }
    iCol = constr[1] - 'a' + 1;
}

// hard-coded
int equals_base(const char *zCol) {
    int length = (int)strlen(zCol) + 1;
    char copy[length], *token;
    memcpy(copy, zCol, length);
    token = strtok(copy, " ");
    if ( token != NULL ) {
	if ( !strcmp(token, "base") )
	    return true;
	else
	    return false;
    } else
	return SQLITE_NOMEM;
}


int Trucks_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    vector<Truck*> *any_dstr = (vector<Truck*> *)stcsr->source;
    vector<Truck*>:: iterator iter;
    int op, iCol, count = 0, i = 0, re = 0, size = get_datastructure_size(cur);
    if ( val==NULL ){
        for (int j=0; j<size; j++){
            stcsr->resultSet[j] = j;
            stcsr->size++;
	}
        assert(stcsr->size <= stcsr->max_size);
        assert(&stcsr->resultSet[stcsr->size] <= &stcsr->resultSet[stcsr->max_size]);
    }else{
	printf("Seaching VT Trucks...makes no sense.\n");
	return SQLITE_MISUSE;
    }
    return SQLITE_OK;
}


int Truck_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Truck *any_dstr;
    int op, iCol, count = 0, i = 0, re = 0;
    if ( stl->zErr ) {
	sqlite3_free(stl->zErr);
	return SQLITE_MISUSE;
    }
    if ( val==NULL ){
	printf("Seaching VT Truck with no BASE constraint...makes no sense.\n");	
	return SQLITE_MISUSE;
    }else{
        check_alloc((const char *)constr, op, iCol);
	if ( equals_base(stl->azColumn[iCol]) ) {
	    vtd_iter = vt_directory.find(stl->zName);
	    if ( (vtd_iter == vt_directory.end()) || (vtd_iter->second == 0) ) {
		printf("Invalid cast to %s\n", stl->zName);
		return SQLITE_MISUSE;
	    }
	    vt_directory[stl->zName] = 0;
	    stcsr->source = (void *)sqlite3_value_int64(val);
	    any_dstr = (Truck *)stcsr->source;
	}
        int *temp_res;
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\n");
            return SQLITE_NOMEM;
        }
        switch( iCol ){
        case 0:
            temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 1:
	    printf("Restricted area. Searching VT Truck column customers...makes no sense.\n");
	    return SQLITE_MISUSE;
        case 2:
            if (compare(any_dstr->get_cost(), op, sqlite3_value_double(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 3:
            if (compare(any_dstr->get_delcapacity(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 4:
            if (compare(any_dstr->get_pickcapacity(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 5:
            if (compare(any_dstr->get_rlpoint(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        }
        if ( (re = compare_res(count, stcsr, temp_res)) != 0 )
            return re;
        sqlite3_free(temp_res);
    }
    return SQLITE_OK;
}


int Customers_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    vector<Customer*> *any_dstr;
    vector<Customer*>:: iterator iter;
    int op, iCol, count = 0, i = 0, re = 0, size = 0;
    if ( stl->zErr ) {
	sqlite3_free(stl->zErr);
	return SQLITE_MISUSE;
    }
    if ( val==NULL ){
	printf("Seaching VT Customers with no BASE constraint...makes no sense.\n");	
	return SQLITE_MISUSE;
    }else{
        check_alloc((const char *)constr, op, iCol);
	if ( equals_base(stl->azColumn[iCol]) ) {
	    vtd_iter = vt_directory.find(stl->zName);
	    if ( (vtd_iter == vt_directory.end()) || (vtd_iter->second == 0) ) {
		printf("Invalid cast to %s\n", stl->zName);
		return SQLITE_MISUSE;
	    }
	    vt_directory[stl->zName] = 0;
	    stcsr->source = (void *)sqlite3_value_int64(val);
	    any_dstr = (vector<Customer*> *)stcsr->source;
	    size = get_datastructure_size(cur);
	    realloc_resultset(cur);
	}
        int *temp_res;
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\n");
            return SQLITE_NOMEM;
        }
        switch( iCol ){
        case 0:
            iter = any_dstr->begin();
            for(int i=0; i<size;i++){
                temp_res[count++] = i;
                iter++;
            }
            assert(count <= stcsr->max_size);
            break;
        case 1:
	    printf("Restricted area.Searching VT Customers column customer_ptr...makes no sense.\n");
	    return SQLITE_MISUSE;
        }
        if ( (re = compare_res(count, stcsr, temp_res)) != 0 )
            return re;
        sqlite3_free(temp_res);
    }
    return SQLITE_OK;
}


int Customer_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Customer *any_dstr;
    int op, iCol, count = 0, i = 0, re = 0;
    if ( stl->zErr ) {
	sqlite3_free(stl->zErr);
	return SQLITE_MISUSE;
    }
    if ( val==NULL ){
	printf("Seaching VT Customer with no BASE constraint...makes no sense.\n");	
	return SQLITE_MISUSE;
    }else{
        check_alloc((const char *)constr, op, iCol);
	if ( equals_base(stl->azColumn[iCol]) ) {
	    vtd_iter = vt_directory.find(stl->zName);
	    if ( (vtd_iter == vt_directory.end()) || (vtd_iter->second == 0) ) {
		printf("Invalid cast to %s\n", stl->zName);
		return SQLITE_MISUSE;
	    }
	    vt_directory[stl->zName] = 0;
	    stcsr->source = (void *)sqlite3_value_int64(val);
	    any_dstr = (Customer *)stcsr->source;
	}
        int *temp_res;
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\n");
            return SQLITE_NOMEM;
        }
        switch( iCol ){
        case 0:
            temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 1:
	    printf("Restricted area.Searching VT Customer column position_ptr...makes no sense.\n");
	    return SQLITE_MISUSE;
        case 2:
            if (compare(any_dstr->get_demand(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 3:
            if (compare((const unsigned char *)any_dstr->get_code().c_str(), op, sqlite3_value_text(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 4:
            if (compare(any_dstr->get_serviced(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 5:
            if (compare(any_dstr->get_pickdemand(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 6:
            if (compare(any_dstr->get_starttime(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 7:
            if (compare(any_dstr->get_servicetime(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 8:
            if (compare(any_dstr->get_finishtime(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 9:
            if (compare(any_dstr->get_revenue(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        }
        if ( (re = compare_res(count, stcsr, temp_res)) != 0 )
            return re;
        sqlite3_free(temp_res);
    }
    return SQLITE_OK;
}


int Position_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Position *any_dstr;
    int op, iCol, count = 0, i = 0, re = 0;
    if ( stl->zErr ) {
	sqlite3_free(stl->zErr);
	return SQLITE_MISUSE;
    }
    if ( val==NULL ){
	printf("Seaching VT Position with no BASE constraint...makes no sense.\n");	
	return SQLITE_MISUSE;
    }else{
        check_alloc((const char *)constr, op, iCol);
	if ( equals_base(stl->azColumn[iCol]) ) {
	    vtd_iter = vt_directory.find(stl->zName);
	    if ( (vtd_iter == vt_directory.end()) || (vtd_iter->second == 0) ) {
		printf("Invalid cast to %s\n", stl->zName);
		return SQLITE_MISUSE;
	    }
	    vt_directory[stl->zName] = 0;
	    stcsr->source = (void *)sqlite3_value_int64(val);
	    any_dstr = (Position *)stcsr->source;
	}
        int *temp_res;
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\n");
            return SQLITE_NOMEM;
        }
        switch( iCol ){
        case 0:
            temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 1:
            if (compare(any_dstr->get_x(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        case 2:
            if (compare(any_dstr->get_y(), op, sqlite3_value_int(val)) )
                temp_res[count++] = i;
            assert(count <= stcsr->max_size);
            break;
        }
        if ( (re = compare_res(count, stcsr, temp_res)) != 0 )
            return re;
        sqlite3_free(temp_res);
    }
    return SQLITE_OK;
}


int MapIndex_search(sqlite3_vtab_cursor *cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    map<int,Customer*> *any_dstr = (map<int,Customer*> *)stcsr->source;
    map<int,Customer*>:: iterator iter;
    int op, iCol, count = 0, i = 0, re = 0, size = get_datastructure_size(cur);
    if ( val==NULL ){
        for (int j=0; j<size; j++){
            stcsr->resultSet[j] = j;
            stcsr->size++;
	}
        assert(stcsr->size <= stcsr->max_size);
        assert(&stcsr->resultSet[stcsr->size] <= &stcsr->resultSet[stcsr->max_size]);
    }else{
        check_alloc((const char *)constr, op, iCol);
        int *temp_res;
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\n");
            return SQLITE_NOMEM;
        }
        switch( iCol ){
        case 0:
            iter = any_dstr->begin();
            for(int i=0; i<size;i++){
                if (compare((*iter).first, op, sqlite3_value_int(val)) )
                    temp_res[count++] = i;
                iter++;
            }
            assert(count <= stcsr->max_size);
            break;
        case 1:
	    printf("Restricted area.Searching VT MapIndex column customer_ptr...makes no sense.\n");
	    return SQLITE_MISUSE;
        }
        if ( (re = compare_res(count, stcsr, temp_res)) != 0 )
            return re;
        sqlite3_free(temp_res);
    }
    return SQLITE_OK;
}


int search(sqlite3_vtab_cursor* cur, char *constr, sqlite3_value *val){
    stlTable *stl = (stlTable *)cur->pVtab;
    if( !strcmp(stl->zName, "Trucks") )
        return Trucks_search(cur, constr, val);
    if( !strcmp(stl->zName, "Truck") )
        return Truck_search(cur, constr, val);
    if( !strcmp(stl->zName, "Customers") )
        return Customers_search(cur, constr, val);
    if( !strcmp(stl->zName, "Customer") )
        return Customer_search(cur, constr, val);
    if( !strcmp(stl->zName, "Position") )
        return Position_search(cur, constr, val);
    if( !strcmp(stl->zName, "MapIndex") )
        return MapIndex_search(cur, constr, val);
}


int Trucks_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    vector<Truck*> *any_dstr = (vector<Truck*> *)stcsr->source;
    vector<Truck*>:: iterator iter;
    int index = stcsr->current;
    iter = any_dstr->begin();
    for(int i=0; i<stcsr->resultSet[index]; i++){
        iter++;
    }
    switch( n ){
    case 0:
	if ( (vtd_iter = vt_directory.find("Truck")) != vt_directory.end() )
	    vtd_iter->second = 1;
        sqlite3_result_int64(con, (long int)*iter);
        break;
    }
    return SQLITE_OK;
}


int Truck_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Truck *any_dstr = (Truck *)stcsr->source;
    switch( n ){
    case 0:
        sqlite3_result_int64(con, (long int)any_dstr);
        break;
    case 1:
	if ( (vtd_iter = vt_directory.find("Customers")) != vt_directory.end() )
	    vtd_iter->second = 1;
        sqlite3_result_int64(con, (long int)any_dstr->get_Customers());
        break;
    case 2:
        sqlite3_result_double(con, any_dstr->get_cost());
        break;
    case 3:
        sqlite3_result_int(con, any_dstr->get_delcapacity());
        break;
    case 4:
        sqlite3_result_int(con, any_dstr->get_pickcapacity());
        break;
    case 5:
        sqlite3_result_int(con, any_dstr->get_rlpoint());
        break;
    }
    return SQLITE_OK;
}


int Customers_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    vector<Customer*> *any_dstr = (vector<Customer*> *)stcsr->source;
    vector<Customer*>:: iterator iter;
    int index = stcsr->current;
    iter = any_dstr->begin();
    for(int i=0; i<stcsr->resultSet[index]; i++){
        iter++;
    }
    switch( n ){
    case 0:
        sqlite3_result_int64(con, (long int)any_dstr);
        break;
    case 1:
	if ( (vtd_iter = vt_directory.find("Customer")) != vt_directory.end() )
	    vtd_iter->second = 1;
        sqlite3_result_int64(con, (long int)*iter);
        break;
    }
    return SQLITE_OK;
}


int Customer_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Customer *any_dstr = (Customer *)stcsr->source;
    switch( n ){
    case 0:
        sqlite3_result_int64(con, (long int)any_dstr);
        break;
    case 1:
	if ( (vtd_iter = vt_directory.find("Position")) != vt_directory.end() )
	    vtd_iter->second = 1;
        sqlite3_result_int64(con, (long int)any_dstr->get_pos());
        break;
    case 2:
        sqlite3_result_int(con, any_dstr->get_demand());
        break;
    case 3:
        sqlite3_result_text(con, (const char *)any_dstr->get_code().c_str(), -1, SQLITE_STATIC);
        break;
    case 4:
        sqlite3_result_int(con, any_dstr->get_serviced());
        break;
    case 5:
        sqlite3_result_int(con, any_dstr->get_pickdemand());
        break;
    case 6:
        sqlite3_result_int(con, any_dstr->get_starttime());
        break;
    case 7:
        sqlite3_result_int(con, any_dstr->get_servicetime());
        break;
    case 8:
        sqlite3_result_int(con, any_dstr->get_finishtime());
        break;
    case 9:
        sqlite3_result_int(con, any_dstr->get_revenue());
        break;
    }
    return SQLITE_OK;
}


int Position_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    Position *any_dstr = (Position *)stcsr->source;
    switch( n ){
    case 0:
        sqlite3_result_int64(con, (long int)any_dstr);
        break;
    case 1:
        sqlite3_result_int(con, any_dstr->get_x());
        break;
    case 2:
        sqlite3_result_int(con, any_dstr->get_y());
        break;
    }
    return SQLITE_OK;
}


int MapIndex_retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTableCursor *stcsr = (stlTableCursor *)cur;
    map<int,Customer*> *any_dstr = (map<int,Customer*> *)stcsr->source;
    map<int,Customer*>:: iterator iter;
    int index = stcsr->current;
    iter = any_dstr->begin();
    for(int i=0; i<stcsr->resultSet[index]; i++){
        iter++;
    }
    switch( n ){
    case 0:
        sqlite3_result_int(con, (*iter).first);
        break;
    case 1:
	if ( (vtd_iter = vt_directory.find("Customer")) != vt_directory.end() )
	    vtd_iter->second = 1;
        sqlite3_result_int64(con, (long int)(*iter).second);
        break;
    }
    return SQLITE_OK;
}


int retrieve(sqlite3_vtab_cursor *cur, int n, sqlite3_context *con){
    stlTable *stl = (stlTable *)cur->pVtab;
    if( !strcmp(stl->zName, "Trucks") )
        return Trucks_retrieve(cur, n, con);
    if( !strcmp(stl->zName, "Truck") )
        return Truck_retrieve(cur, n, con);
    if( !strcmp(stl->zName, "Customers") )
        return Customers_retrieve(cur, n, con);
    if( !strcmp(stl->zName, "Customer") )
        return Customer_retrieve(cur, n, con);
    if( !strcmp(stl->zName, "Position") )
        return Position_retrieve(cur, n, con);
    if( !strcmp(stl->zName, "MapIndex") )
        return MapIndex_retrieve(cur, n, con);
}
